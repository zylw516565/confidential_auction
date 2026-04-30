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

    const connectWallet = async () => {
        try {
            if (typeof window.ethereum !== 'undefined') {
                const web3Provider = new ethers.providers.Web3Provider(window.ethereum);
                await web3Provider.send("eth_requestAccounts", []);
                const web3Signer = web3Provider.getSigner();
                const address = await web3Signer.getAddress();

                setProvider(web3Provider);
                setSigner(web3Signer);
                setUserAddress(address);
                showMessage('钱包连接成功！', 'success');
            } else {
                showMessage('请安装MetaMask钱包！', 'error');
            }
        } catch (error) {
            console.error('连接钱包失败:', error);
            showMessage('连接钱包失败: ' + error.message, 'error');
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
                    <div className="form-group">
                        <label>NFT合约地址</label>
                        <input
                            type="text"
                            value={auctionData.nftContractAddress}
                            onChange={(e) => setAuctionData({...auctionData, nftContractAddress: e.target.value})}
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
                        <label>竞拍时长（小时）</label>
                        <input
                            type="number"
                            value={auctionData.bidPeriod}
                            onChange={(e) => setAuctionData({...auctionData, bidPeriod: e.target.value})}
                            placeholder="24"
                            min="1"
                        />
                    </div>
                    <div className="form-group">
                        <label>保留价格（ETH）</label>
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
