# 🔐 NFT拍卖系统 (NFT Auction System)

一个基于以太坊区块链的NFT拍卖系统，采用第二价格拍卖机制，确保拍卖过程的公平性和隐私性。

## 📋 目录

- [项目简介](#项目简介)
- [功能特性](#功能特性)
- [技术架构](#技术架构)
- [智能合约说明](#智能合约说明)
- [前端应用说明](#前端应用说明)
- [安装部署](#安装部署)
- [使用教程](#使用教程)
- [安全注意事项](#安全注意事项)
- [项目截图](#项目截图)
- [开发指南](#开发指南)
- [常见问题](#常见问题)
- [许可证](#许可证)

## 🎯 项目简介

NFT拍卖系统是一个去中心化的NFT拍卖平台，基于以太坊智能合约构建。系统采用第二价格拍卖机制（Vickrey拍卖），获胜者只需支付第二高出价的价格，这种机制能够鼓励参与者真实出价，提高拍卖效率。

### 核心特性

- **第二价格拍卖机制**：获胜者支付第二高出价，鼓励真实出价
- **NFT资产支持**：完全兼容ERC721标准的NFT代币
- **防重入攻击**：集成OpenZeppelin的ReentrancyGuard保护
- **自动化结算**：拍卖结束后自动执行资产转移和资金分配

## ✨ 功能特性

### 智能合约功能

- ✅ 创建拍卖：设置NFT、竞拍时长、保留价格
- ✅ 参与竞拍：提交出价
- ✅ 结束拍卖：自动结算并转移资产
- ✅ 提取抵押品：非获胜者取回出价资金
- ✅ 查询信息：实时查看拍卖状态和出价情况

### 前端应用功能

- 🔐 MetaMask钱包集成
- 📝 NFT授权管理
- 🎨 直观的用户界面
- 📊 实时状态更新
- ⚡ 快速交易处理
- 📱 响应式设计

## 🏗️ 技术架构

```
拍卖系统
├── 智能合约层 (Solidity 0.8.33)
│   ├── ConfidentialAuction.sol - 主拍卖合约
│   ├── IConfidentialAuctionErrors.sol - 错误接口
│   └── OpenZeppelin - 安全库依赖
├── 前端应用层 (React 18)
│   ├── App.js - 主应用组件
│   ├── App.css - 样式文件
│   └── Ethers.js - 区块链交互库
└── 开发工具 (Foundry)
    ├── Forge - 编译和测试
    ├── Cast - 合约交互
    └── Anvil - 本地节点
```

## 📜 智能合约说明

### 核心数据结构

```solidity
struct Auction {
    address seller;              // 卖家地址
    uint32  endOfBiddingPeriod;  // 竞拍结束时间
    bool    started;              // 拍卖是否开始
    uint32  count;                // 竞拍次数
    uint256 topBid;               // 最高出价
    uint256 secondTopBid;        // 第二高出价
    uint256 reservePrice;         // 保留价格
    address topBidder;            // 最高出价者
}

struct BidInfo {
    uint256 bidValue;            // 出价金额
    address tokenContract;        // NFT合约地址
    uint256 tokenId;             // NFT Token ID
}
```

### 主要函数

#### 1. 创建拍卖
```solidity
function createAuction(
    address tokenContract,  // NFT合约地址
    uint256 tokenId,        // NFT Token ID
    uint32  bidPeriod,     // 竞拍时长（秒）
    uint64  reservePrice    // 保留价格（wei）
) external nonReentrant
```

**要求：**
- NFT必须已授权给拍卖合约
- 竞拍时长最少5分钟
- 卖家必须拥有该NFT

#### 2. 参与竞拍
```solidity
function bid(
    address tokenContract,  // NFT合约地址
    uint256 tokenId         // NFT Token ID
) external payable nonReentrant
```

**要求：**
- 出价必须大于保留价格
- 每个地址只能出价一次
- 必须在竞拍期内

#### 3. 结束拍卖
```solidity
function endAuction(
    address tokenContract,  // NFT合约地址
    uint256 tokenId         // NFT Token ID
) external nonReentrant
```

**结算逻辑：**
- 无出价：NFT退还给卖家
- 有出价：NFT转给最高出价者，卖家获得第二高出价
- 最高出价者获得差价退款

#### 4. 提取抵押品
```solidity
function withdrawCollateral(
    address tokenContract,  // NFT合约地址
    uint256 tokenId         // NFT Token ID
) external nonReentrant
```

**适用对象：** 非获胜出价者

### 事件

```solidity
event AuctionCreated(
    address indexed tokenContract,
    uint256 indexed tokenId,
    address indexed seller,
    uint32 bidPeriod,
    uint256 reservePrice
);

event Bidded(
    address indexed tokenContract,
    uint256 indexed tokenId
);
```

## 🎨 前端应用说明

### 技术栈

- **React 18** - 用户界面框架
- **Ethers.js 5.7** - 区块链交互库
- **MetaMask** - 钱包集成
- **CSS3** - 样式设计

### 主要组件

#### 1. 钱包连接
- 自动检测MetaMask
- 账户切换监听
- 网络状态显示

#### 2. NFT授权
- ERC721 approve函数集成
- 授权状态查询
- 实时状态更新

#### 3. 创建拍卖
- 参数输入验证
- 交易状态跟踪
- 错误处理和提示

#### 4. 参与竞拍
- 出价金额输入
- 实时余额检查
- 交易确认流程

#### 5. 拍卖管理
- 拍卖信息查询
- 结束拍卖操作
- 抵押品提取

## 🚀 安装部署

### 前置要求

- Node.js >= 14.0.0
- npm 或 yarn
- MetaMask浏览器扩展
- Git

### 智能合约部署

#### 1. 安装Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### 2. 编译合约

```bash
cd confidential_auction
forge build
```

#### 3. 运行测试

```bash
forge test
```

#### 4. 部署合约

```bash
# 部署到本地测试网络
anvil &
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网络（如Sepolia）
forge script script/Deploy.s.sol --rpc-url https://sepolia.infura.io/v3/YOUR_KEY --broadcast --verify --etherscan-api-key YOUR_API_KEY
```

### 前端应用部署

#### 1. 安装依赖

```bash
cd frontend
npm install
```

#### 2. 配置环境变量

创建 `.env` 文件：

```env
REACT_APP_AUCTION_CONTRACT_ADDRESS=0x...
REACT_APP_NETWORK_ID=11155111  # Sepolia测试网
```

#### 3. 启动开发服务器

```bash
npm start
```

应用将在 http://localhost:3000 启动

#### 4. 构建生产版本

```bash
npm run build
```

#### 5. 部署到静态托管

```bash
# 部署到Netlify
npm install -g netlify-cli
netlify deploy --prod --dir=build

# 部署到Vercel
vercel --prod
```

## 📖 使用教程

### 第一步：连接钱包

1. 打开应用，点击右上角"连接钱包"按钮
2. 在MetaMask中授权连接
3. 确保连接到正确的网络（测试网或主网）

### 第二步：授权NFT

1. 在"创建拍卖"区域，输入NFT合约地址和Token ID
2. 输入要授权的地址（拍卖合约地址）
3. 点击"授权NFT"按钮
4. 在MetaMask中确认授权交易
5. 等待交易确认

![授权界面](1.png)

### 第三步：创建拍卖

1. 在"拍卖设置"区域，设置竞拍参数：
   - 竞拍时长（小时）
   - 保留价格（ETH）
2. 点击"创建拍卖"按钮
3. 在MetaMask中确认交易
4. 等待交易确认

![创建拍卖界面](2.png)

### 第四步：参与竞拍

1. 切换到竞拍者账户
2. 在"出价"区域，输入拍卖信息
3. 输入出价金额（必须大于保留价格）
4. 点击"出价"按钮
5. 在MetaMask中确认交易

### 第五步：结束拍卖

1. 等待竞拍期结束
2. 在"拍卖管理"区域，点击"结束拍卖"按钮
3. 系统自动结算：
   - NFT转移给最高出价者
   - ETH转移给卖家
   - 差价退还给最高出价者

### 第六步：提取抵押品

1. 非获胜出价者可以在拍卖结束后提取自己的出价
2. 在"拍卖管理"区域，点击"提取抵押品"按钮
3. 等待交易确认

## 🔒 安全注意事项

### 智能合约安全

- ✅ 防重入攻击保护
- ✅ 输入参数验证
- ✅ 权限控制检查
- ✅ 紧急暂停机制

### 用户安全

- 🔐 始终验证合约地址
- 🧪 先在测试网测试
- 💰 注意Gas费用
- 🔑 保护私钥和助记词
- ✅ 仔细检查交易详情

### 最佳实践

1. **测试优先**：在主网部署前充分测试
2. **小额测试**：首次使用时用小额资金测试
3. **定期审计**：定期进行安全审计
4. **备份重要**：备份重要的交易哈希和合约地址
5. **保持更新**：及时更新依赖库和安全补丁

## 📸 项目截图

### 界面展示

#### 1. NFT授权界面
![NFT授权界面](1.png)

用户可以通过此界面授权拍卖合约操作其NFT资产，确保拍卖流程的顺利进行。

#### 2. 创建拍卖界面
![创建拍卖界面](2.png)

创建拍卖的主界面，用户可以设置拍卖参数并启动新的NFT拍卖。

## 🛠️ 开发指南

### 项目结构

```
confidential_auction/
├── src/
│   ├── ConfidentialAuction.sol       # 主拍卖合约
│   └── IConfidentialAuctionErrors.sol # 错误接口
├── script/
│   └── Deploy.s.sol                  # 部署脚本
├── test/
│   └── ConfidentialAuction.t.sol     # 测试文件
├── frontend/
│   ├── src/
│   │   ├── App.js                    # 主应用组件
│   │   ├── App.css                   # 样式文件
│   │   └── index.js                  # 入口文件
│   ├── public/
│   │   └── index.html                # HTML模板
│   └── package.json                  # 依赖配置
├── foundry.toml                      # Foundry配置
├── foundry.lock                      # 依赖锁定
└── README.md                         # 项目文档
```

### 智能合约开发

#### 编译合约

```bash
forge build
```

#### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试
forge test --match-test testCreateAuction

# 显示Gas使用情况
forge test --gas-report

# 显示详细输出
forge test -vvv
```

#### 代码格式化

```bash
forge fmt
```

#### 代码检查

```bash
forge check
```

### 前端开发

#### 启动开发服务器

```bash
cd frontend
npm start
```

#### 运行测试

```bash
npm test
```

#### 代码检查

```bash
npm run lint
```

### 贡献指南

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## ❓ 常见问题

### Q1: 为什么我的出价失败了？

**A:** 请检查以下几点：
- 出价金额是否大于保留价格
- 是否在竞拍期内
- 是否已经出价过（每个地址只能出价一次）
- 账户余额是否足够

### Q2: 如何知道我是否赢得了拍卖？

**A:** 你可以通过"查询拍卖信息"功能查看：
- 检查"最高出价者"是否为你的地址
- 确认拍卖状态为"已结束"

### Q3: 拍卖结束后多久可以提取抵押品？

**A:** 拍卖结束后，非获胜出价者可以立即提取自己的出价资金。

### Q4: 如果没有人出价会怎样？

**A:** 如果没有人出价或出价未达到保留价格：
- NFT将退还给卖家
- 卖家可以重新创建拍卖

### Q5: Gas费用大概多少？

**A:** Gas费用取决于网络拥堵情况：
- 创建拍卖：约100,000-200,000 gas
- 出价：约50,000-100,000 gas
- 结束拍卖：约150,000-300,000 gas

### Q6: 支持哪些网络？

**A:** 目前支持：
- Ethereum主网
- Sepolia测试网
- Goerli测试网
- 任何EVM兼容网络

### Q7: 如何切换网络？

**A:** 在MetaMask中：
1. 点击网络名称
2. 选择或添加自定义网络
3. 刷新前端页面

## 📞 联系方式

- 项目地址：[GitHub Repository](https://github.com/zylw516565/confidential_auction)
- 问题反馈：[Issues](https://github.com/zylw516565/confidential_auction/issues)
- 邮箱：zylw516565@163.com

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [OpenZeppelin](https://openzeppelin.com/) - 提供安全的智能合约库
- [Foundry](https://getfoundry.sh/) - 强大的以太坊开发工具包
- [Ethers.js](https://docs.ethers.io/) - 以太坊JavaScript库
- [React](https://reactjs.org/) - 用户界面框架

---

**⚠️ 免责声明：本软件按"原样"提供，不提供任何形式的明示或暗示保证。使用本软件的风险由使用者自行承担。**