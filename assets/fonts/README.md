# 字体

## MaShanZheng-Regular.ttf

- **字体**：Ma Shan Zheng（马善政毛笔楷书）
- **来源**：Google Fonts — https://fonts.google.com/specimen/Ma+Shan+Zheng
- **许可**：SIL Open Font License 1.1（见同目录 `OFL.txt`），可商用、可嵌入
- **用途**：界面装饰字——标题、问候语、主按钮、区块标签、日期。
  **不用于用户输入的正文**（正文用系统字体，保证可读性与字号缩放表现）
- **体积**：约 5.6MB。中文字体先天就大；若日后需要压体积，
  可用 fonttools 子集化到界面实际用到的字符集，但要注意：
  用户自定义标签的名字会因此回退到系统字体。

## 为什么不用 Zhi Mang Xing

原型里它是 Ma Shan Zheng 的回退字体。两者叠加会把体积翻倍，
而页面实际排版中回退几乎不会被触发，因此只打包主字体。
