# AMCA3D

AMCA3D 是一个用于增材制造过程中介观晶粒组织演化模拟的并行 C++ 程序，核心方法为三维元胞自动机方法（3D Cellular Automata）。程序通过 MPI 并行运行，输入文件采用 YAML 格式，结果可使用 ParaView 等工具进行可视化。

## 运行环境

当前仓库已按以下环境完成适配和编译验证：

- 平台：星河超算
- 操作系统：Rocky Linux 8.10
- MPI：通过环境模块加载 MPICH，默认模块名为 `mpich/3.2`
- 编译器：`mpicc`、`mpicxx`
- 构建工具：CMake、make
- 依赖库：Boost、yaml-cpp、pthread
- YAML 解析库：系统包 `yaml-cpp-devel`，已适配 yaml-cpp 0.6.x 接口
- 可视化工具：ParaView

本版本不再要求手工安装旧版 yaml-cpp 0.3.0。若系统已安装 `yaml-cpp-devel`，可直接使用系统库编译。

## 编译方法

仓库提供统一编译脚本 `compile.sh`。当前推荐并已验证的方式是通过该脚本编译 MPICH 版本的 AMCA3D。在星河超算 Rocky Linux 8.10 环境下，进入仓库根目录后执行：

```bash
./compile.sh
```

脚本默认执行以下操作：

- 清理并重新创建 `build` 目录
- 若系统支持 `module` 命令，则加载 `mpich/3.2`
- 使用 `mpicc` 和 `mpicxx` 作为 C/C++ 编译器
- 检查 CMake、make、MPI 编译器和 yaml-cpp
- 调用 CMake 配置工程
- 使用多核并行执行 `make`

编译成功后，可执行文件位于：

```bash
build/AMCA3D
```

## 编译脚本参数

`compile.sh` 支持通过环境变量调整编译行为。指定并行编译线程数：

```bash
JOBS=8 ./compile.sh
```

复用已有 `build` 目录进行增量编译：

```bash
CLEAN=0 ./compile.sh
```

生成 Debug 构建：

```bash
BUILD_TYPE=Debug ./compile.sh
```

指定需要加载的 MPI 模块（默认值为 `mpich/3.2`）：

```bash
MPI_MODULE=mpich/3.2 ./compile.sh
```

跳过模块加载，使用当前 shell 环境中的 MPI：

```bash
LOAD_MPI_MODULE=0 ./compile.sh
```

加载 MPICH 前不执行 `module purge`：

```bash
PURGE_MODULES=0 ./compile.sh
```

如果 Boost 或 yaml-cpp 安装在非系统路径，可通过以下变量传入：

```bash
BOOST_ROOT=/path/to/boost YAML_ROOT=/path/to/yaml-cpp ./compile.sh
```

## yaml-cpp 兼容性说明

旧版 AMCA3D 代码使用 yaml-cpp 0.3 风格接口，例如 `YAML::Parser`、`FindValue`、`YAML::Iterator` 和 `GetMark()`。Rocky Linux 8.10 的 `yaml-cpp-devel` 提供的是较新的 yaml-cpp 0.6.x 接口，因此旧代码会在编译阶段出现 YAML 相关错误。

当前代码已完成迁移：

- 使用 `YAML::Load` 读取输入文件
- 使用 `node["key"]` 查询 YAML 节点
- 使用 `YAML::const_iterator` 遍历节点
- 使用 `node.Mark()` 获取错误位置
- 通过 `node.as<T>()` 完成标量类型转换

因此在星河超算 Rocky Linux 8.10 环境中，无需回退安装旧版 yaml-cpp。

## 运行案例与教程

完成编译后，以下案例均从仓库根目录下的 `example` 目录运行。案例脚本会把 `build/AMCA3D` 复制到当前算例目录，然后通过 `mpirun` 启动并行计算。

### 均匀温度场形核案例

该案例展示在均匀温度场和恒定冷却速率下的形核过程。形核点随机分布在计算域中，临界过冷度服从高斯分布。

运行方法：

```bash
cd example/nucleation
./nucleation.sh
```

`nucleation.sh` 的主要内容为：

```bash
cp ../../build/AMCA3D ./
mpirun -np 4 ./AMCA3D -i Inputfile.i -o run.log
```

其中 `-np 4` 表示使用 4 个 MPI 进程；`-i Inputfile.i` 指定输入文件；`-o run.log` 指定运行日志。计算完成后，结果通常输出到 `Results` 目录，可使用 ParaView 打开 `Grains.pvd` 或最终的 `.vtk` 文件查看晶粒结构。

![形核案例中的晶粒结构结果](./FIGURE/Nucleation.png)

该案例的核心输入参数位于 `realms` 部分，例如：

```yaml
realms:
  - name: realm1
    type: cellular_automata
    dimension: 3

    domain:
      type: cubic
      original_point: [0,0,0]
      lateral_sizes: [0.03, 0.03, 0.03]

    discretization:
      cell_size: 0.0005

    nucleation_rules:
      - surface:
          type: Gaussian
          site_density: 0.0
          mean: 2
          standard_deviation: 0.5

      - bulk:
          type: Gaussian
          site_density: 10e6
          mean: 3
          standard_deviation: 1

    problem_physics:
        type: RappazGandin
        initial_temperature: -0.2
        melting_temperature: 0.0
        t_dot: -20
        a1: -0.544e-4
        a2: 2.03e-4
        a3: 0.0
```

`domain` 和 `discretization` 设置计算域位置、尺寸和元胞尺寸。`nucleation_rules` 设置表面与体内形核密度以及临界过冷度分布。`problem_physics` 设置初始温度、冷却速率、熔点以及枝晶尖端生长动力学参数。

### 增材制造温度场案例

增材制造案例需要读入热过程模拟得到的 `.txt` 温度场文件。AMCA3D 会将粗网格温度结果插值到细元胞自动机网格中，从而计算晶粒组织演化。典型的热分析粗网格和 CA 细网格关系如下图所示。

![粗网格热分析计算域与细网格 CA 计算域](./FIGURE/DOMAIN.png)

当前仓库提供两个粉末床熔融（PBF）案例：

- `example/PBF_AM/PBF_x`
- `example/PBF_AM/PBF_y`

### PBF_x

`PBF_x` 案例展示在给定温度场文件下的晶粒生长演化。

运行方法：

```bash
cd example/PBF_AM/PBF_x
./PBF_x.sh
```

`PBF_x.sh` 的主要内容为：

```bash
cp ../../../build/AMCA3D ./
unzip PBF_x.zip
wait $!
mpirun -np 4 ./AMCA3D -i Inputfile.i -o run.log
```

计算完成后，可在 ParaView 中查看晶粒演化和插值后的温度场结果。

![PBF_x 晶粒生长演化和插值温度场](./FIGURE/PBF_x.png)

该案例首先在 `solvers` 部分启用两个求解器：

```yaml
solvers:
   - cellular_automata
   - finite_element_method
```

其中 `cellular_automata` 用于晶粒组织演化，`finite_element_method` 用于把粗网格温度场映射到细 CA 网格。

输入文件中还需要定义 `transfers` 部分，用于控制 CA 网格和 FEM 网格之间的数据传递。其中 `void_temperature` 是重要参数：温度低于该阈值的单元会被视为空隙或非激活区域，温度重新高于阈值后可再次激活，从而模拟粉末颗粒间空隙的影响。

有限元温度场对应的 `realm` 示例为：

```yaml
- name: realm0
    type: finite_element
    dimension: 3
    mesh: ./PBF_x.txt

    solution_options:
       name: my_options

       options:
         - load_data_from_file:
             theta: theta
             for_whole_time: yes
             length_scale: 10.0
             time_scale: 1.0
             lines_for_title: 4
             lines_for_subtitle: 5
             x_offset: 0
             z_offset: 0

    output:
      output_data_base_name: ./Results/FEM
      output_frequency: 200000
      output_time_interval: 0.0002
      output_variables:
        - temperature
```

`mesh` 指定温度场文件路径。`length_scale` 和 `time_scale` 用于统一 CA 与热分析模型之间的长度、时间单位。`x_offset` 和 `z_offset` 用于调整温度场位置。`lines_for_title` 和 `lines_for_subtitle` 用于适配温度文件的标题行和副标题行。

温度场文件通常由标题、副标题和数据三部分组成，例如：

```text
Title:
Temperature file example
2022/04/13
End of title

Subtitle (the second line)
No. step   No. step    time   time   x0    x1   y0   y1    z0   z1
   1          1         0       0     0     1    0    1     0    1
x  y  z  tn
0  0  0  293
1  0  0  293
0  1  0  293
1  1  0  293
0  0  1  293
1  0  1  293
0  1  1  293
1  1  1  293

Subtitle (the second line)
No. step   No. step    time   time   x0    x1   y0   y1    z0   z1
   2          2         0.1    0.1     0     1    0    1     0    1
x  y  z  tn
0  0  0  300
1  0  0  300
0  1  0  300
1  1  0  300
0  0  1  300
1  0  1  300
0  1  1  300
1  1  1  300
```

标题部分可选，副标题和数据部分必须存在。副标题中包含步数、时间和空间范围信息。数据部分给出每个点的坐标和温度值。当前程序支持结构化六面体网格，数据行数需要和网格点数量一致，点数据应按 `(X, Y, Z)` 顺序排列。

### PBF_y

`PBF_y` 案例展示多道或多层增材制造过程中如何使用已有结果初始化后续计算。脚本会先运行一个预计算形核案例，然后把预计算得到的晶粒信息作为后续熔化计算的初始组织。

运行方法：

```bash
cd example/PBF_AM/PBF_y
./PBF_y.sh
```

`PBF_y.sh` 的主要内容为：

```bash
cp ../../../build/AMCA3D ./
unzip PBF_y.zip
wait $!
mkdir PreRun
cd PreRun
cp ../AMCA3D ./
mpirun -np 4 ./AMCA3D -i ../Inputfile_0.i -o run_0.log
wait $!
cd ..
mpirun -np 4 ./AMCA3D -i Inputfile_1.i -o run_1.log
```

运行结果如下图所示，左侧为预运行形核结果，右侧为使用该结果初始化后的 PBF_y 计算结果。

![PBF_y 预运行结果和重启动后的计算结果](./FIGURE/PBF_y.png)

这种方式对应重启动策略。程序通过读取上一阶段输出的晶粒信息文件初始化当前计算。输入文件中通常需要在 `solution_options` 下配置输出和读取晶粒信息，例如：

```yaml
- output_microstructure_information:
    file_name: grainInfo.txt
    output_seeds: yes
- load_microstructure_information:
    file_name: ./PreRun/grainInfo.txt
```

使用重启动策略时，应保证前后两次计算的计算域尺寸和 MPI 进程数一致，否则可能导致网格和晶粒信息无法正确对应。

## 输入文件

AMCA3D 使用 YAML 格式输入文件。典型输入文件包括：

- `realms`：计算域、维度、网格尺寸、物理模型和输出配置
- `solvers`：启用的求解器，例如 `cellular_automata` 或 `finite_element_method`
- `nucleation_rules`：形核位置、形核密度和临界过冷度分布
- `problem_physics`：初始温度、熔点、冷却速率和枝晶尖端生长动力学参数
- `solution_options`：温度场文件、重启动、输出频率等运行选项

可从 `example/nucleation/Inputfile.i` 和 `example/PBF_AM` 下的输入文件开始修改。

## 常见问题

### 编译时报 yaml-cpp 错误

请确认使用的是本仓库当前代码，并通过 `compile.sh` 重新清理编译：

```bash
./compile.sh
```

若仍然报错，检查系统是否安装 yaml-cpp 开发包：

```bash
rpm -qa | grep yaml-cpp
```

Rocky Linux 8.10 上通常需要安装 `yaml-cpp-devel`。

### 找不到 mpicc 或 mpicxx

确认已加载 MPICH 模块：

```bash
module load mpich/3.2
which mpicc
which mpicxx
```

也可以直接让 `compile.sh` 自动加载默认模块。

### 需要更换 MPICH 版本

如果星河超算环境提供其他 MPICH 模块，可通过 `MPI_MODULE` 指定：

```bash
MPI_MODULE=<module-name> ./compile.sh
```

## 联系与引用

如果基于 AMCA3D 开展研究，请引用相关论文并注明代码来源。原项目联系方式为 [yanping.lian@bit.edu.cn](mailto:yanping.lian@bit.edu.cn)。

[1] F.Y. Xiong, Z.T. Gan, J.W. Chen, Y.P. Lian*. Evaluate the effect of melt pool convection on grain structure in selective laser melted IN625 alloy using experimentally validated process-structure modeling. Journal of Materials Processing Technology, 303:117538, 2022.

[2] F.Y. Xiong, C.Y. Huang, O. L. Kafka, Y. P. Lian*, W.T. Yan, M.J. Chen, D.N. Fang. Grain growth prediction in selective electron beam melting of Ti-6Al-4V with a cellular automaton method. Materials & Design, 199:109410, 2021.

[3] L.C. Geng, B. Zhang, Y.P. Lian*, R.X. Gao, D.N. Fang*. An image-based multi-level hp FCM for predicting elastoplastic behavior of imperfect lattice structure by SLM. Computational Mechanics, 2022.

[4] D. Kats, Z. Wang, Z. Gan, W.K. Liu, G. J. Wagner, Y.P. Lian*. A physics-informed machine learning method for predicting grain structure characteristics in directed energy deposition. Computational Materials Science, 202:110958, 2021.

[5] 廉艳平*，王潘丁，高杰，等. 金属增材制造若干关键力学问题研究进展. 力学进展，51(3):648-701, 2021. (Y.P. Lian*, P.D. Wang, J. Gao, et al. Fundamental mechanics problems in metal additive manufacturing: A state-of-art review. Advances in Mechanics, 51(3):648-701, 2021).

[6] 黄辰阳，陈嘉伟，朱言言，廉艳平*. 激光定向能量沉积的粉末尺度多物理场数值模拟. 力学学报，53(12):3240-3251, 2021. (C.Y. Huang, J.W. Chen, Y.Y. Zhu, Y.P. Lian*. Powder scale multiphysics numerical modeling of laser directed energy deposition. Chinese Journal of Theoretical and Applied Mechanics, 53(12):3240-3251, 2021).

[7] 陈嘉伟，熊飞宇，黄辰阳，廉艳平. 金属增材制造数值模拟. 中国科学: 物理学 力学 天文学, 50(9):09007, 2020. (J.W. Chen, F.Y. Xiong, C.Y. Huang, Y.P. Lian. Numerical simulation on metal additive manufacturing. Science Sinica Physica, Mechanica & Astronomica, 50(9):09007, 2020).

[8] Y.P. Lian*, Z. Gan, C. Yu, D. Kats, W.K. Liu, G.J. Wagner. A cellular automaton finite volume method for microstructure evolution during additive manufacturing. Materials & Design, 169:107672, 2019.

[9] Y.P. Lian, S. Lin, W.T. Yan, W.K. Liu, G.J. Wagner*. A parallelized three-dimensional cellular automaton model for grain growth during additive manufacturing. Computational Mechanics, 61:543-559, 2018.

[10] Z. Gan#, Y.P. Lian#, S. Lin, K. Jones, W.K. Liu*, G. Wagner*. Benchmark study of thermal behavior, surface topography, and dendritic microstructure in selective laser melting of Inconel 625. Integrating Materials and Manufacturing Innovation, 8:178-193, 2019.

[11] W.T. Yan#, Y.P. Lian#, C. Yu, O. Kafka, Z.L. Liu, W.K. Liu, G. Wagner*. An integrated process-structure-property modeling framework for additive manufacturing. Computer Methods in Applied Mechanics and Engineering, 339:184-204, 2018.
