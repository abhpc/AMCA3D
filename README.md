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

`compile.sh` 支持通过环境变量调整编译行为：

```bash
JOBS=8 ./compile.sh
```

指定并行编译线程数。

```bash
CLEAN=0 ./compile.sh
```

复用已有 `build` 目录进行增量编译。

```bash
BUILD_TYPE=Debug ./compile.sh
```

生成 Debug 构建。

```bash
MPI_MODULE=mpich/3.2 ./compile.sh
```

指定需要加载的 MPI 模块。默认值为 `mpich/3.2`。

```bash
LOAD_MPI_MODULE=0 ./compile.sh
```

跳过模块加载，使用当前 shell 环境中的 MPI。

```bash
PURGE_MODULES=0 ./compile.sh
```

加载 MPICH 前不执行 `module purge`。

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

## 运行示例

完成编译后，可运行均匀温度场形核算例：

```bash
cd example/nucleation
cp ../../build/AMCA3D ./
mpirun -np 4 ./AMCA3D -i Inputfile.i -o run.log
```

粉末床熔融算例位于：

```text
example/PBF_AM/PBF_x
example/PBF_AM/PBF_y
```

对应脚本为：

```bash
cd example/PBF_AM/PBF_x
./PBF_x.sh
```

```bash
cd example/PBF_AM/PBF_y
./PBF_y.sh
```

运行结果通常输出到算例目录下的 `Results` 或 `result` 目录。可使用 ParaView 打开 `.pvd`、`.vtk`、`.vtu` 或 `.vtr` 文件查看晶粒组织和温度场结果。

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

## 引用

如果基于 AMCA3D 开展研究，请引用相关论文并注明代码来源。

[1] F.Y. Xiong, Z.T. Gan, J.W. Chen, Y.P. Lian*. Evaluate the effect of melt pool convection on grain structure in selective laser melted IN625 alloy using experimentally validated process-structure modeling. Journal of Materials Processing Technology, 303:117538, 2022.

[2] F.Y. Xiong, C.Y. Huang, O. L. Kafka, Y. P. Lian*, W.T. Yan, M.J. Chen, D.N. Fang. Grain growth prediction in selective electron beam melting of Ti-6Al-4V with a cellular automaton method. Materials & Design, 199:109410, 2021.

[3] Y.P. Lian*, Z. Gan, C. Yu, D. Kats, W. K. Liu, G. J. Wagner. A cellular automaton finite volume method for microstructure evolution during additive manufacturing. Materials & Design, 169:107672, 2019.

[4] Y.P. Lian, S. Lin, W.T. Yan, W.K. Liu, G.J. Wagner*. A parallelized three-dimensional cellular automaton model for grain growth during additive manufacturing. Computational Mechanics, 61:543-559, 2018.
