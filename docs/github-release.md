# GitHub 发布准备清单

建议公开仓库名：`zhiti-learning`  
建议仓库简介：`An offline-first quiz practice and learning analytics app. Import your own question banks, practice locally, and review mistakes.`

推荐 Topics：`quiz-app`、`question-bank`、`learning-tools`、`offline-first`、`exam-preparation`、`edtech`。

## 发布前人工确认

- 确认发布者有权按 MIT 许可发布本项目中的应用代码。
- 确认“知题 / ZHITI”品牌名称和标识的使用权；保留品牌不等于完成商标检索或注册。
- 确认演示题为项目作者原创；检查工作区内不包含原 V6.2 HTML、未经许可题库或学习备份。
- 在 GitHub 仓库设置中开启私密漏洞报告；选择 Pages 部署来源为 GitHub Actions。
- 首次真实浏览器验收：桌面、手机宽度、单选练习、判断练习、错题、评论、报告、题库导入与刷新后数据保存。
- 首发可使用 `v0.1.0` 标签；待跨浏览器检查、导入与迁移规则成熟后再考虑 `v1.0.0`。

## 发布后检查

- 确认 GitHub Actions 的测试和 Pages 部署均成功。
- 检查公开页面和下载包中不含原题库、个人备份或密钥。
- 在 README 添加已验证的在线演示链接和页面截图；当前候选尚未生成浏览器截图。
- 建立一个 `v0.1.0` Release，并上传离线 ZIP。
