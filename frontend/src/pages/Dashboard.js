import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import api from '../utils/api';
import PriceChart from '../components/PriceChart';
import IndicatorPanel from '../components/IndicatorPanel';
import SignalPanel from '../components/SignalPanel';
import PortfolioPanel from '../components/PortfolioPanel';
import TradePanel from '../components/TradePanel';
import AutoTradingPanel from '../components/AutoTradingPanel';
import ControlPanel from '../components/ControlPanel';
import './Dashboard.css';

const Dashboard = () => {
  const { user, logout } = useAuth();
  const [tickers, setTickers] = useState([]);
  const [selectedTicker, setSelectedTicker] = useState('AAPL');
  const [prices, setPrices] = useState([]);
  const [indicators, setIndicators] = useState({});
  const [signal, setSignal] = useState({ action: 'HOLD', confidence: 0.5, reason: 'Loading...' });
  const [account, setAccount] = useState({ cash_balance: 0 });
  const [portfolio, setPortfolio] = useState([]);
  const [trades, setTrades] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchTickers();

    const interval = setInterval(() => {
      fetchData();
    }, 5000); // Auto-refresh every 5 seconds
    return () => clearInterval(interval);
  }, [selectedTicker]);


  const updateSelectedTicker = (ticker) => {
    setSelectedTicker(ticker);
    setIsLoading(true);
  };

  const fetchTickers = async () => {
    try {
      const response = await api.get('/tickers');
      setTickers(response.data);
      console.log('Fetched tickers:', response.data);
      if (response.data.length > 0 && !selectedTicker) {
        setSelectedTicker(response.data[0].symbol);
      }
    } catch (error) {
      console.error('Error fetching tickers:', error);
    }
  };

  const fetchData = async () => {
    try {
      const [pricesRes, indicatorsRes, signalRes, accountRes, portfolioRes, tradesRes] = await Promise.all([
        api.get(`/tickers/${selectedTicker}/prices`),
        api.get(`/tickers/${selectedTicker}/indicators`),
        api.get(`/tickers/${selectedTicker}/signal`),
        api.get('/account'),
        api.get('/portfolio'),
        api.get('/trades'),
      ]);

      setPrices(pricesRes.data);
      setIndicators(indicatorsRes.data);
      setSignal(signalRes.data);
      setAccount(accountRes.data);
      setPortfolio(portfolioRes.data);
      setTrades(tradesRes.data);
      setIsLoading(false);
    } catch (error) {
      console.error('Error fetching data:', error);
    }
  };

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="header-left">
          <h1 className="dashboard-title">Trading Dashboard</h1>
          <select 
            value={selectedTicker}
            onChange={(e) => updateSelectedTicker(e.target.value)}
            className="ticker-selector"
          >
            {tickers.map(ticker => (
              <option key={ticker.id} value={ticker.symbol}>
                {ticker.symbol} - {ticker.name}
              </option>
            ))}
          </select>
        </div>
        <div className="header-right">
          <span className="user-info">Welcome, {user?.username}</span>
          <button onClick={logout} className="logout-button">Logout</button>
        </div>
      </header>
      {
          <div className="dashboard-grid fade-in">
            <div className="grid-item chart-area">
              {
                isLoading ? (
                  <div className="loading-indicator">Loading price chart...</div>
                ) : (
                      <PriceChart prices={prices} />
                )
              }
            </div>
            <div className="grid-item indicators-area">
              {
                isLoading ? (
                  <div className="loading-indicator">Loading Indicator chart...</div>
                ) : (
                      <IndicatorPanel indicators={indicators} />
                )
              }
            </div>
            <div className="grid-item signal-area">
              {
                isLoading ? (
                  <div className="loading-indicator">Loading Signal chart...</div>
                ) : (
                      <SignalPanel signal={signal} />
                )
              }
            </div>
            <div className="grid-item portfolio-area">
              <PortfolioPanel account={account} portfolio={portfolio} />
            </div>
            <div className="grid-item trades-area">
              <TradePanel trades={trades} />
            </div>
            <div className="grid-item auto-area">
              <AutoTradingPanel />
            </div>
            <div className="grid-item control-area">
              <ControlPanel ticker={selectedTicker} onTradeComplete={fetchData} />
            </div>
          </div>
      }
    </div>
  );
};

export default Dashboard;
