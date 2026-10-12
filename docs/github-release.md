# 仓库发布与维护状态

仓库：<https://github.com/jin-shanghai/zhiti-learning>  
当前版本：`v1.1.0`（VERSION 文件 `1.1.0`）

## 正式发布

- 发布页面：<https://github.com/jin-shanghai/zhiti-learning/releases/latest>
- 在线体验：<https://jin-shanghai.github.io/zhiti-learning/>
- 分发内容：内置600题的离线单文件 HTML，以及带使用说明的离线 ZIP。
- 发布工作流在 VERSION 或工作流文件变更并进入主分支时运行，在完成代码与浏览器回归测试后创建版本标签和 Release；如果同名 Release 已存在则退出，避免重复发布。

## 已发布

- 公开源代码、MIT 许可证、NOTICE、题库格式及使用说明。
- 中英文 README 产品介绍和四张由测试流程生成的界面截图，位于 `docs/images/`。
- v1.1.0 增加自动连续答题、用户自配置 AI 和本地缓存解题教练。
- GitHub Actions 静态与浏览器交互检查、截图更新流程；Pages 采用 GitHub 原生发布，移除失败的重复部署工作流。

## 仍需核对

- Pages 采用 GitHub 原生发布；每次合并后需确认正式页面已显示新功能。
- 仓库维护者应确认代码与演示素材有权依 MIT 发布；名称说明不等于商标注册。
- 已增加桌面和手机视口的浏览器回归测试；仍建议在真实手机、Safari、Edge 上人工复核题库导入与恢复。
- 如开启私密漏洞报告，可将 SECURITY.md 的首选报告路径指向该入口。
- 每次后续发布新的版本标签前，确认网页版本、截图、题库版本和文档一致。

## 推荐仓库 Topics

`quiz-app`、`question-bank`、`learning-tools`、`offline-first`、`exam-preparation`、`edtech`。
