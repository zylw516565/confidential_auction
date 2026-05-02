import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import './App.css';

const AUCTION_ABI = [
    "function createAuction(address tokenContract, uint256 tokenId, uint32 bidPeriod, uint64 reservePrice) external",
    "function bid(address tokenContract, uint256 tokenId) external payable",
    "function endAuction(address tokenContract, uint256 tokenId) external",
    "function withdrawCollateral(address tokenContract, uint256 tokenId) external",
    "function getAuction(address tokenContract, uint256 tokenId) external view returns (tuple(address seller, uint32 endOfBiddingPeriod, bool started, uint32 count, uint256 topBid, uint256 secondTopBid, uint256 reservePrice, address topBidder))",
    "function getBidInfo(address tokenContract, uint256 tokenId, address bidder) external view returns (tuple(uint256 bidValue, address tokenContract, uint256 tokenId))",
    "event AuctionCreated(address indexed tokenContract, uint256 indexed tokenId, address indexed seller, uint32 bidPeriod, uint256 reservePrice)",
    "event Bidded(address indexed tokenContract, uint256 indexed tokenId)"
];

const ERC721_ABI = [
    "function approve(address to, uint256 tokenId) public",
    "function getApproved(uint256 tokenId) public view returns (address)",
    "function ownerOf(uint256 tokenId) public view returns (address)",
    "event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)"
];

function App() {
    const [provider, setProvider] = useState(null);
    const [signer, setSigner] = useState(null);
    const [userAddress, setUserAddress] = useState('');
    const [auctionContractAddress, setAuctionContractAddress] = useState('');
    const [contract, setContract] = useState(null);
    const [message, setMessage] = useState({ text: '', type: '' });
    const [loading, setLoading] = useState(false);

    const [auctionData, setAuctionData] = useState({
        nftContractAddress: '',
        tokenId: '',
        bidPeriod: '24',
        reservePrice: ''
    });

    const [bidData, setBidData] = useState({
        nftContractAddress: '',
        tokenId: '',
        bidAmount: ''
    });

    const [auctionInfo, setAuctionInfo] = useState(null);
    const [queryData, setQueryData] = useState({
        nftContractAddress: '',
        tokenId: ''
    });

    const [approveData, setApproveData] = useState({
        nftContractAddress: '',
        tokenId: '',
        approvedAddress: ''
    });
    const [approvalStatus, setApprovalStatus] = useState({
        isApproved: false,
        approvedAddress: '',
        owner: ''
    });

    useEffect(() => {
        if (window.ethereum) {
            window.ethereum.on('accountsChanged', handleAccountsChanged);
        }
        return () => {
            if (window.ethereum) {
                window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
            }
        };
    }, []);

    const handleAccountsChanged = (accounts) => {
        if (accounts.length > 0) {
            setUserAddress(accounts[0]);
        } else {
            setUserAddress('');
            setSigner(null);
        }
    };

    // 设置Provider和Signer
    const setupProviderAndSigner = async (address) => {
        try {
            const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
            setProvider(web3Provider);
            
            const web3Signer = web3Provider.getSigner();
            setSigner(web3Signer);
            setUserAddress(address);

            // 验证网络
            const network = await web3Provider.getNetwork();
            console.log("当前钱包网络 chainId:", network.chainId);
            console.log("当前地址:", address);
            
        } catch (error) {
            console.error('设置Provider失败:', error);
            showMessage('钱包连接异常: ' + error.message, 'error');
        }
    };

    // 手动连接钱包
    const connectWallet = async () => {
        try {
            if (!window.ethereum) {
                showMessage('请安装MetaMask钱包！', 'error');
                return;
            }

            setLoading(true);
            // 请求账户授权
            const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
            
            if (accounts.length > 0) {
                await setupProviderAndSigner(accounts[0]);
                showMessage('钱包连接成功！', 'success');
            }
        } catch (error) {
            console.error('连接钱包失败:', error);
            showMessage('连接钱包失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const initContract = () => {
        if (auctionContractAddress && signer) {
            const auctionContract = new ethers.Contract(auctionContractAddress, AUCTION_ABI, signer);
            setContract(auctionContract);
        }
    };

    useEffect(() => {
        initContract();
    }, [auctionContractAddress, signer]);

    const showMessage = (text, type) => {
        setMessage({ text, type });
        setTimeout(() => setMessage({ text: '', type: '' }), 5000);
    };

    const approveNFT = async () => {
        if (!signer) {
            showMessage('请先连接钱包', 'error');
            return;
        }

        if (!approveData.nftContractAddress || !approveData.tokenId || !approveData.approvedAddress) {
            showMessage('请填写所有必填字段', 'error');
            return;
        }

        try {
            setLoading(true);
            const nftContract = new ethers.Contract(approveData.nftContractAddress, ERC721_ABI, signer);
            
            const tx = await nftContract.approve(approveData.approvedAddress, approveData.tokenId);
            showMessage('授权交易已提交，等待确认...', 'info');
            await tx.wait();
            showMessage('NFT授权成功！', 'success');
            
            await checkApprovalStatus();
        } catch (error) {
            console.error('NFT授权失败:', error);
            showMessage('NFT授权失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const checkApprovalStatus = async () => {
        if (!provider || !approveData.nftContractAddress || !approveData.tokenId) {
            return;
        }

        try {
            const nftContract = new ethers.Contract(approveData.nftContractAddress, ERC721_ABI, provider);
            const code = await provider.getCode(nftContract.address);
            const code2 = await provider.getCode(auctionContractAddress);

            const approvedAddress = await nftContract.getApproved(approveData.tokenId);
            const owner = await nftContract.ownerOf(approveData.tokenId);
            
            setApprovalStatus({
                isApproved: approvedAddress !== '0x0000000000000000000000000000000000000000',
                approvedAddress: approvedAddress,
                owner: owner
            });
        } catch (error) {
            console.error('查询授权状态失败:', error);
            setApprovalStatus({
                isApproved: false,
                approvedAddress: '',
                owner: ''
            });
        }
    };

    const createAuction = async () => {
        if (!contract) {
            showMessage('请先设置拍卖合约地址', 'error');
            return;
        }

        try {
            setLoading(true);
            const bidPeriodSeconds = parseInt(auctionData.bidPeriod) * 3600;
            const reservePriceWei = ethers.utils.parseEther(auctionData.reservePrice);

            const tx = await contract.createAuction(
                auctionData.nftContractAddress,
                auctionData.tokenId,
                bidPeriodSeconds,
                reservePriceWei
            );

            showMessage('交易已提交，等待确认...', 'info');
            await tx.wait();
            showMessage('拍卖创建成功！', 'success');
        } catch (error) {
            console.error('创建拍卖失败:', error);
            showMessage('创建拍卖失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const placeBid = async () => {
        if (!contract) {
            showMessage('请先设置拍卖合约地址', 'error');
            return;
        }

        try {
            setLoading(true);
            const bidAmountWei = ethers.utils.parseEther(bidData.bidAmount);

            const tx = await contract.bid(
                bidData.nftContractAddress,
                bidData.tokenId,
                { value: bidAmountWei }
            );

            showMessage('交易已提交，等待确认...', 'info');
            await tx.wait();
            showMessage('出价成功！', 'success');
        } catch (error) {
            console.error('出价失败:', error);
            showMessage('出价失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const endAuction = async () => {
        if (!contract) {
            showMessage('请先设置拍卖合约地址', 'error');
            return;
        }

        try {
            setLoading(true);
            const tx = await contract.endAuction(
                queryData.nftContractAddress,
                queryData.tokenId
            );

            showMessage('交易已提交，等待确认...', 'info');
            await tx.wait();
            showMessage('拍卖结束成功！', 'success');
        } catch (error) {
            console.error('结束拍卖失败:', error);
            showMessage('结束拍卖失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const withdrawCollateral = async () => {
        if (!contract) {
            showMessage('请先设置拍卖合约地址', 'error');
            return;
        }

        try {
            setLoading(true);
            const tx = await contract.withdrawCollateral(
                queryData.nftContractAddress,
                queryData.tokenId
            );

            showMessage('交易已提交，等待确认...', 'info');
            await tx.wait();
            showMessage('抵押品提取成功！', 'success');
        } catch (error) {
            console.error('提取抵押品失败:', error);
            showMessage('提取抵押品失败: ' + error.message, 'error');
        } finally {
            setLoading(false);
        }
    };

    const queryAuctionInfo = async () => {
        if (!auctionContractAddress) {
            showMessage('请先设置拍卖合约地址', 'error');
            return;
        }

        try {
            const queryContract = new ethers.Contract(auctionContractAddress, AUCTION_ABI, provider);
            const auction = await queryContract.getAuction(queryData.nftContractAddress, queryData.tokenId);
            const bidInfo = await queryContract.getBidInfo(queryData.nftContractAddress, queryData.tokenId, userAddress);

            setAuctionInfo({
                seller: auction.seller,
                endOfBiddingPeriod: auction.endOfBiddingPeriod,
                started: auction.started,
                count: auction.count,
                topBid: auction.topBid,
                secondTopBid: auction.secondTopBid,
                reservePrice: auction.reservePrice,
                topBidder: auction.topBidder,
                myBid: bidInfo.bidValue
            });
        } catch (error) {
            console.error('查询拍卖信息失败:', error);
            showMessage('查询拍卖信息失败: ' + error.message, 'error');
        }
    };

    const formatAddress = (address) => {
        if (!address || address === '0x0000000000000000000000000000000000000000') return '无';
        return `${address.substring(0, 6)}...${address.substring(38)}`;
    };

    const formatEther = (wei) => {
        return ethers.utils.formatEther(wei);
    };

    const isAuctionEnded = (endTime) => {
        return Date.now() > endTime * 1000;
    };

    return (
        <div className="App">
            <header className="header">
                <h1>🔐 保密拍卖系统</h1>
                <div className="wallet-section">
                    <span className="wallet-address">
                        {userAddress ? formatAddress(userAddress) : '未连接钱包'}
                    </span>
                    <button 
                        className="btn btn-primary" 
                        onClick={connectWallet}
                        disabled={!!userAddress}
                    >
                        {userAddress ? '已连接' : '连接钱包'}
                    </button>
                </div>
            </header>

            {message.text && (
                <div className={`message ${message.type}`}>
                    {message.text}
                </div>
            )}

            <main className="main-content">
                <section className="card">
                    <h2>合约设置</h2>
                    <div className="form-group">
                        <label>拍卖合约地址</label>
                        <input
                            type="text"
                            value={auctionContractAddress}
                            onChange={(e) => setAuctionContractAddress(e.target.value)}
                            placeholder="0x..."
                        />
                    </div>
                </section>

                <section className="card">
                    <h2>创建拍卖</h2>
                    
                    <div className="approval-section">
                        <h3>🔐 NFT授权</h3>
                        <div className="form-group">
                            <label>NFT合约地址</label>
                            <input
                                type="text"
                                value={approveData.nftContractAddress}
                                onChange={(e) => {
                                    setApproveData({...approveData, nftContractAddress: e.target.value});
                                    setAuctionData({...auctionData, nftContractAddress: e.target.value});
                                }}
                                placeholder="0x..."
                            />
                        </div>
                        <div className="form-group">
                            <label>NFT Token ID</label>
                            <input
                                type="number"
                                value={approveData.tokenId}
                                onChange={(e) => {
                                    setApproveData({...approveData, tokenId: e.target.value});
                                    setAuctionData({...auctionData, tokenId: e.target.value});
                                }}
                                placeholder="0"
                            />
                        </div>
                        <div className="form-group">
                            <label>授权给地址</label>
                            <input
                                type="text"
                                value={approveData.approvedAddress}
                                onChange={(e) => setApproveData({...approveData, approvedAddress: e.target.value})}
                                placeholder={auctionContractAddress || "0x..."}
                            />
                        </div>
                        <div className="approval-actions">
                            <button 
                                className="btn btn-primary" 
                                onClick={checkApprovalStatus}
                                disabled={!userAddress}
                            >
                                查询授权状态
                            </button>
                            <button 
                                className="btn btn-success" 
                                onClick={approveNFT}
                                disabled={loading || !userAddress}
                            >
                                {loading ? <span className="loading"></span> : '授权NFT'}
                            </button>
                        </div>
                        
                        {approvalStatus.owner && (
                            <div className="approval-status">
                                <div className="status-item">
                                    <strong>NFT所有者:</strong> {formatAddress(approvalStatus.owner)}
                                </div>
                                <div className="status-item">
                                    <strong>授权状态:</strong> 
                                    <span className={`status-badge ${approvalStatus.isApproved ? 'status-active' : 'status-ended'}`}>
                                        {approvalStatus.isApproved ? '已授权' : '未授权'}
                                    </span>
                                </div>
                                {approvalStatus.isApproved && (
                                    <div className="status-item">
                                        <strong>授权给:</strong> {formatAddress(approvalStatus.approvedAddress)}
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                    
                    <div className="divider"></div>
                    
                    <h3>📝 拍卖设置</h3>
                    <div className="form-group">
                        <label>NFT合约地址</label>
                        <input
                            type="text"
                            value={auctionData.nftContractAddress}
                            onChange={(e) => {
                                setAuctionData({...auctionData, nftContractAddress: e.target.value});
                                setApproveData({...approveData, nftContractAddress: e.target.value});
                            }}
                            placeholder="0x..."
                        />
                    </div>
                    <div className="form-group">
                        <label>NFT Token ID</label>
                        <input
                            type="number"
                            value={auctionData.tokenId}
                            onChange={(e) => setAuctionData({...auctionData, tokenId: e.target.value})}
                            placeholder="0"
                        />
                    </div>
                    <div className="form-group">
                        <label>竞拍时长（秒）</label>
                        <input
                            type="number"
                            value={auctionData.bidPeriod}
                            onChange={(e) => setAuctionData({...auctionData, bidPeriod: e.target.value})}
                            placeholder="24"
                            min="1"
                        />
                    </div>
                    <div className="form-group">
                        <label>保留价格（wei）</label>
                        <input
                            type="number"
                            value={auctionData.reservePrice}
                            onChange={(e) => setAuctionData({...auctionData, reservePrice: e.target.value})}
                            placeholder="0.1"
                            step="0.01"
                            min="0"
                        />
                    </div>
                    <button 
                        className="btn btn-primary" 
                        onClick={createAuction}
                        disabled={loading || !userAddress}
                    >
                        {loading ? <span className="loading"></span> : '创建拍卖'}
                    </button>
                    <p className="warning-text">
                        <strong>**注意：**</strong> 创建拍卖前，您需要先授权智能合约操作您的NFT。
                    </p>
                </section>

                <section className="card">
                    <h2>出价</h2>
                    <div className="form-group">
                        <label>NFT合约地址</label>
                        <input
                            type="text"
                            value={bidData.nftContractAddress}
                            onChange={(e) => setBidData({...bidData, nftContractAddress: e.target.value})}
                            placeholder="0x..."
                        />
                    </div>
                    <div className="form-group">
                        <label>NFT Token ID</label>
                        <input
                            type="number"
                            value={bidData.tokenId}
                            onChange={(e) => setBidData({...bidData, tokenId: e.target.value})}
                            placeholder="0"
                        />
                    </div>
                    <div className="form-group">
                        <label>出价金额（ETH）</label>
                        <input
                            type="number"
                            value={bidData.bidAmount}
                            onChange={(e) => setBidData({...bidData, bidAmount: e.target.value})}
                            placeholder="0.1"
                            step="0.01"
                            min="0"
                        />
                    </div>
                    <button 
                        className="btn btn-success" 
                        onClick={placeBid}
                        disabled={loading || !userAddress}
                    >
                        {loading ? <span className="loading"></span> : '出价'}
                    </button>
                </section>

                <section className="card">
                    <h2>拍卖管理</h2>
                    <div className="form-group">
                        <label>NFT合约地址</label>
                        <input
                            type="text"
                            value={queryData.nftContractAddress}
                            onChange={(e) => setQueryData({...queryData, nftContractAddress: e.target.value})}
                            placeholder="0x..."
                        />
                    </div>
                    <div className="form-group">
                        <label>NFT Token ID</label>
                        <input
                            type="number"
                            value={queryData.tokenId}
                            onChange={(e) => setQueryData({...queryData, tokenId: e.target.value})}
                            placeholder="0"
                        />
                    </div>
                    <div className="auction-actions">
                        <button 
                            className="btn btn-primary" 
                            onClick={queryAuctionInfo}
                            disabled={loading}
                        >
                            查询信息
                        </button>
                        <button 
                            className="btn btn-danger" 
                            onClick={endAuction}
                            disabled={loading || !userAddress}
                        >
                            {loading ? <span className="loading"></span> : '结束拍卖'}
                        </button>
                        <button 
                            className="btn btn-warning" 
                            onClick={withdrawCollateral}
                            disabled={loading || !userAddress}
                        >
                            {loading ? <span className="loading"></span> : '提取抵押品'}
                        </button>
                    </div>
                </section>

                {auctionInfo && (
                    <section className="card full-width">
                        <h2>拍卖详情</h2>
                        <div className="auction-item">
                            <div className="auction-info">
                                <div className="auction-info-item">
                                    <strong>卖家:</strong> {formatAddress(auctionInfo.seller)}
                                </div>
                                <div className="auction-info-item">
                                    <strong>状态:</strong> 
                                    <span className={`status-badge ${isAuctionEnded(auctionInfo.endOfBiddingPeriod) ? 'status-ended' : 'status-active'}`}>
                                        {isAuctionEnded(auctionInfo.endOfBiddingPeriod) ? '已结束' : '进行中'}
                                    </span>
                                </div>
                                <div className="auction-info-item">
                                    <strong>结束时间:</strong> {new Date(auctionInfo.endOfBiddingPeriod * 1000).toLocaleString()}
                                </div>
                                <div className="auction-info-item">
                                    <strong>保留价格:</strong> {formatEther(auctionInfo.reservePrice)} ETH
                                </div>
                                <div className="auction-info-item">
                                    <strong>当前最高出价:</strong> {formatEther(auctionInfo.topBid)} ETH
                                </div>
                                <div className="auction-info-item">
                                    <strong>第二高出价:</strong> {formatEther(auctionInfo.secondTopBid)} ETH
                                </div>
                                <div className="auction-info-item">
                                    <strong>最高出价者:</strong> {formatAddress(auctionInfo.topBidder)}
                                </div>
                                <div className="auction-info-item">
                                    <strong>竞拍次数:</strong> {auctionInfo.count}
                                </div>
                            </div>
                            <div className="auction-info-item">
                                <strong>我的出价:</strong> {formatEther(auctionInfo.myBid)} ETH
                            </div>
                        </div>
                    </section>
                )}
            </main>
        </div>
    );
}

export default App;