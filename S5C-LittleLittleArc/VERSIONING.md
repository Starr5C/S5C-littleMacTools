# 版本编号规则

本项目采用语义化版本号 `MAJOR.MINOR.PATCH`，当前版本为 `0.1.0`。

- `0.MINOR.PATCH` 表示项目仍处于 1.0 之前的验证阶段。新增用户可见能力或改变使用流程时递增 `MINOR`；兼容性修复、稳定性改进、文档和测试调整递增 `PATCH`。
- 进入稳定可用边界后发布 `1.0.0`；之后只有不兼容的使用方式、数据格式或接口变化才递增 `MAJOR`。
- 预发布版本使用 `-alpha.N`、`-beta.N` 或 `-rc.N` 后缀，例如 `0.2.0-beta.1`。预发布后缀用于 Git 标签和发布记录，不写入 macOS 的短版本字段。
- `VERSION` 保存对外发布版本，`BUILD_NUMBER` 保存递增的数字构建号。构建产物将版本写入 `CFBundleShortVersionString`，将构建号写入 `CFBundleVersion`，因此两者都能从项目源文件复核。

一次版本发布至少应同步更新 `VERSION`、必要时递增 `BUILD_NUMBER`、更新 README 中的当前版本，并创建对应的 Git 标签；在本集合仓库中使用 `S5C-LittleLittleArc/v<version>` 形式避免与其他工具冲突。未达到稳定可用边界前，不使用 `1.0.x` 作为项目版本。
