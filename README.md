# 包管理器

最简单的 dotfiles 管理方案：Git + Symlink。

## 结构

```
包管理器/
├── config/          # 配置文件存放（按软件名分文件夹）
├── scripts/
│   ├── install.ps1  # 一键创建所有 symlink
│   ├── add.ps1      # 添加一个配置文件到仓库
│   └── remove.ps1   # 移除一个配置的 symlink
└── manifest.json    # 记录所有映射关系
```

## 用法

### 添加一个配置（比如 nvim）
```powershell
.\scripts\add.ps1 nvim "C:\Users\fadedwind\AppData\Local\nvim"
```
这会把原始配置移到 `config/nvim/`，然后在原位创建 symlink 指向它。

### 一键部署所有配置（新机器）
```powershell
.\scripts\install.ps1
```

### 移除一个配置的 symlink
```powershell
.\scripts\remove.ps1 nvim
```

## 同步到其他机器
```powershell
git remote add origin <你的仓库地址>
git push -u origin main
# 新机器上
git clone <仓库地址> G:\包管理器
.\scripts\install.ps1
```
