#!/bin/bash

# Script to generate React trading dashboard with auth and trading UI
set -e

echo "🚀 Generating React Trading Dashboard..."

# Create frontend directory structure
mkdir -p frontend/{src/{components,contexts,utils,pages},public,nginx}

cd frontend

# Create package.json
cat > package.json << 'EOF'
{
  "name": "trading-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "axios": "^1.6.2",
    "recharts": "^2.10.3",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOF

# Create public/index.html
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#0a0e27" />
    <meta name="description" content="AI-Powered Trading Dashboard" />
    <title>Trading Dashboard</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

# Create src/index.js
cat > src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create src/index.css
cat > src/index.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background: #0a0e27;
  color: #ffffff;
  overflow-x: hidden;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}

/* Scrollbar styling */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
}

::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

/* Animations */
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

@keyframes shimmer {
  0% {
    background-position: -1000px 0;
  }
  100% {
    background-position: 1000px 0;
  }
}

.fade-in {
  animation: fadeIn 0.5s ease-out;
}

.pulse {
  animation: pulse 2s ease-in-out infinite;
}
EOF

# Create src/utils/api.js
cat > src/utils/api.js << 'EOF'
import axios from 'axios';

const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
EOF

# Create src/contexts/AuthContext.js
cat > src/contexts/AuthContext.js << 'EOF'
import React, { createContext, useState, useContext, useEffect } from 'react';
import api from '../utils/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      fetchUser();
    } else {
      setLoading(false);
    }
  }, []);

  const fetchUser = async () => {
    try {
      const response = await api.get('/auth/me');
      setUser(response.data);
    } catch (error) {
      localStorage.removeItem('token');
    } finally {
      setLoading(false);
    }
  };

  const login = async (username, password) => {
    const response = await api.post('/auth/login', { username, password });
    localStorage.setItem('token', response.data.access_token);
    await fetchUser();
  };

  const register = async (email, username, password) => {
    await api.post('/auth/register', { email, username, password });
    await login(username, password);
  };

  const logout = () => {
    localStorage.removeItem('token');
    setUser(null);
    window.location.href = '/login';
  };

  return (
    <AuthContext.Provider value={{ user, login, register, logout, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};
EOF

# Create src/components/ProtectedRoute.js
cat > src/components/ProtectedRoute.js << 'EOF'
import { Navigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

const ProtectedRoute = ({ children }) => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        background: '#0a0e27'
      }}>
        <div className="pulse" style={{ fontSize: '24px', color: '#00d4ff' }}>
          Loading...
        </div>
      </div>
    );
  }

  return user ? children : <Navigate to="/login" />;
};

export default ProtectedRoute;
EOF

# Create src/pages/LoginForm.js
cat > src/pages/LoginForm.js << 'EOF'
import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import './Auth.css';

const LoginForm = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await login(username, password);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card fade-in">
        <h1 className="auth-title">Trading Dashboard</h1>
        <p className="auth-subtitle">Sign in to your account</p>
        
        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label>Username</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Enter username"
              required
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password"
              required
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button type="submit" className="auth-button" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

        <p className="auth-footer">
          Don't have an account? <Link to="/register">Register</Link>
        </p>
      </div>
    </div>
  );
};

export default LoginForm;
EOF

# Create src/pages/RegisterForm.js
cat > src/pages/RegisterForm.js << 'EOF'
import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import './Auth.css';

const RegisterForm = () => {
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { register } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await register(email, username, password);
      navigate('/');
    } catch (err) {
      setError(err.response?.data?.detail || 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card fade-in">
        <h1 className="auth-title">Trading Dashboard</h1>
        <p className="auth-subtitle">Create your account</p>
        
        <form onSubmit={handleSubmit} className="auth-form">
          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="Enter email"
              required
            />
          </div>

          <div className="form-group">
            <label>Username</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="Enter username"
              required
              minLength={3}
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="Enter password (8-72 chars)"
              required
              minLength={8}
              maxLength={72}
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button type="submit" className="auth-button" disabled={loading}>
            {loading ? 'Creating account...' : 'Register'}
          </button>
        </form>

        <p className="auth-footer">
          Already have an account? <Link to="/login">Sign in</Link>
        </p>
      </div>
    </div>
  );
};

export default RegisterForm;
EOF

# Create src/pages/Auth.css
cat > src/pages/Auth.css << 'EOF'
.auth-container {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  padding: 20px;
  background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
}

.auth-card {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  padding: 40px;
  width: 100%;
  max-width: 450px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.auth-title {
  font-size: 32px;
  font-weight: 700;
  text-align: center;
  margin-bottom: 10px;
  background: linear-gradient(135deg, #00d4ff 0%, #0099ff 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.auth-subtitle {
  text-align: center;
  color: rgba(255, 255, 255, 0.6);
  margin-bottom: 30px;
  font-size: 16px;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-group label {
  font-size: 14px;
  font-weight: 500;
  color: rgba(255, 255, 255, 0.8);
}

.form-group input {
  padding: 12px 16px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #ffffff;
  font-size: 15px;
  transition: all 0.3s ease;
}

.form-group input:focus {
  outline: none;
  border-color: #00d4ff;
  background: rgba(255, 255, 255, 0.08);
}

.form-group input::placeholder {
  color: rgba(255, 255, 255, 0.3);
}

.error-message {
  padding: 12px;
  background: rgba(255, 82, 82, 0.1);
  border: 1px solid rgba(255, 82, 82, 0.3);
  border-radius: 10px;
  color: #ff5252;
  font-size: 14px;
  text-align: center;
}

.auth-button {
  padding: 14px;
  background: linear-gradient(135deg, #00d4ff 0%, #0099ff 100%);
  border: none;
  border-radius: 10px;
  color: #ffffff;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.3s ease;
  margin-top: 10px;
}

.auth-button:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(0, 212, 255, 0.3);
}

.auth-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.auth-footer {
  text-align: center;
  margin-top: 20px;
  color: rgba(255, 255, 255, 0.6);
  font-size: 14px;
}

.auth-footer a {
  color: #00d4ff;
  text-decoration: none;
  font-weight: 600;
}

.auth-footer a:hover {
  text-decoration: underline;
}
EOF

# Create src/components/PriceChart.js
cat > src/components/PriceChart.js << 'EOF'
import React from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import './Components.css';

const PriceChart = ({ prices }) => {
  const chartData = prices.slice(-50).map((tick, index) => ({
    time: new Date(tick.timestamp).toLocaleTimeString(),
    price: tick.price,
  }));

  return (
    <div className="panel">
      <h2 className="panel-title">Price Chart</h2>
      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.1)" />
          <XAxis 
            dataKey="time" 
            stroke="rgba(255,255,255,0.5)"
            tick={{ fontSize: 12 }}
          />
          <YAxis 
            stroke="rgba(255,255,255,0.5)"
            tick={{ fontSize: 12 }}
            domain={['auto', 'auto']}
          />
          <Tooltip
            contentStyle={{
              background: 'rgba(10, 14, 39, 0.95)',
              border: '1px solid rgba(255,255,255,0.2)',
              borderRadius: '10px',
              color: '#fff'
            }}
          />
          <Line 
            type="monotone" 
            dataKey="price" 
            stroke="#00d4ff" 
            strokeWidth={2}
            dot={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};

export default PriceChart;
EOF

# Create src/components/IndicatorPanel.js
cat > src/components/IndicatorPanel.js << 'EOF'
import React from 'react';
import './Components.css';

const IndicatorPanel = ({ indicators }) => {
  const formatValue = (value) => {
    if (value === null || value === undefined) return 'N/A';
    return typeof value === 'number' ? value.toFixed(2) : value;
  };

  const indicatorsList = [
    { label: 'SMA (20)', value: indicators.sma_20 },
    { label: 'SMA (50)', value: indicators.sma_50 },
    { label: 'EMA (12)', value: indicators.ema_12 },
    { label: 'EMA (26)', value: indicators.ema_26 },
    { label: 'RSI (14)', value: indicators.rsi_14 },
    { label: 'MACD', value: indicators.macd },
  ];

  return (
    <div className="panel">
      <h2 className="panel-title">Technical Indicators</h2>
      <div className="indicators-grid">
        {indicatorsList.map((indicator, index) => (
          <div key={index} className="indicator-item">
            <div className="indicator-label">{indicator.label}</div>
            <div className="indicator-value">{formatValue(indicator.value)}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

export default IndicatorPanel;
EOF

# Create src/components/SignalPanel.js
cat > src/components/SignalPanel.js << 'EOF'
import React from 'react';
import './Components.css';

const SignalPanel = ({ signal }) => {
  const getActionColor = (action) => {
    switch (action) {
      case 'BUY':
        return '#00ff88';
      case 'SELL':
        return '#ff5252';
      default:
        return '#ffa726';
    }
  };

  return (
    <div className="panel">
      <h2 className="panel-title">AI Trading Signal</h2>
      <div className="signal-content">
        <div className="signal-action" style={{ color: getActionColor(signal.action) }}>
          {signal.action}
        </div>
        <div className="confidence-container">
          <div className="confidence-label">
            Confidence: {(signal.confidence * 100).toFixed(0)}%
          </div>
          <div className="confidence-bar">
            <div 
              className="confidence-fill"
              style={{ 
                width: `${signal.confidence * 100}%`,
                background: `linear-gradient(90deg, ${getActionColor(signal.action)}, ${getActionColor(signal.action)}aa)`
              }}
            />
          </div>
        </div>
        <div className="signal-reason">{signal.reason}</div>
      </div>
    </div>
  );
};

export default SignalPanel;
EOF

# Create src/components/PortfolioPanel.js
cat > src/components/PortfolioPanel.js << 'EOF'
import React from 'react';
import './Components.css';

const PortfolioPanel = ({ account, portfolio }) => {
  const calculateTotals = () => {
    let totalInvested = 0;
    let totalValue = 0;

    portfolio.forEach(position => {
      totalInvested += position.avg_price * position.quantity;
      totalValue += (position.current_price || position.avg_price) * position.quantity;
    });

    const pnl = totalValue - totalInvested;
    const pnlPercent = totalInvested > 0 ? (pnl / totalInvested) * 100 : 0;

    return {
      cash: account.cash_balance,
      invested: totalInvested,
      value: totalValue,
      pnl,
      pnlPercent
    };
  };

  const totals = calculateTotals();

  return (
    <div className="panel">
      <h2 className="panel-title">Portfolio</h2>
      <div className="portfolio-cards">
        <div className="portfolio-card">
          <div className="card-label">Cash</div>
          <div className="card-value">${totals.cash.toFixed(2)}</div>
        </div>
        <div className="portfolio-card">
          <div className="card-label">Invested</div>
          <div className="card-value">${totals.invested.toFixed(2)}</div>
        </div>
        <div className="portfolio-card">
          <div className="card-label">Value</div>
          <div className="card-value">${totals.value.toFixed(2)}</div>
        </div>
        <div className="portfolio-card">
          <div className="card-label">P&L</div>
          <div 
            className="card-value"
            style={{ color: totals.pnl >= 0 ? '#00ff88' : '#ff5252' }}
          >
            {totals.pnl >= 0 ? '+' : ''}{totals.pnl.toFixed(2)}
            <span style={{ fontSize: '14px', marginLeft: '5px' }}>
              ({totals.pnlPercent.toFixed(2)}%)
            </span>
          </div>
        </div>
      </div>
      
      {portfolio.length > 0 && (
        <div className="positions-list">
          <h3 className="positions-title">Positions</h3>
          {portfolio.map((position, index) => {
            const positionPnl = ((position.current_price || position.avg_price) - position.avg_price) * position.quantity;
            const positionPnlPercent = ((position.current_price || position.avg_price) / position.avg_price - 1) * 100;
            
            return (
              <div key={index} className="position-item">
                <div className="position-symbol">{position.ticker_symbol}</div>
                <div className="position-details">
                  <span>{position.quantity} shares @ ${position.avg_price.toFixed(2)}</span>
                  <span 
                    style={{ 
                      color: positionPnl >= 0 ? '#00ff88' : '#ff5252',
                      fontWeight: 600 
                    }}
                  >
                    {positionPnl >= 0 ? '+' : ''}{positionPnl.toFixed(2)} ({positionPnlPercent.toFixed(2)}%)
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default PortfolioPanel;
EOF

# Create src/components/TradePanel.js
cat > src/components/TradePanel.js << 'EOF'
import React from 'react';
import './Components.css';

const TradePanel = ({ trades }) => {
  return (
    <div className="panel">
      <h2 className="panel-title">Trade History</h2>
      <div className="trades-container">
        {trades.length === 0 ? (
          <div className="empty-state">No trades yet</div>
        ) : (
          <table className="trades-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Symbol</th>
                <th>Action</th>
                <th>Qty</th>
                <th>Price</th>
                <th>Total</th>
              </tr>
            </thead>
            <tbody>
              {trades.slice(0, 10).map((trade, index) => (
                <tr key={index}>
                  <td>{new Date(trade.timestamp).toLocaleTimeString()}</td>
                  <td>{trade.ticker_symbol}</td>
                  <td>
                    <span 
                      className="trade-action"
                      style={{ color: trade.action === 'BUY' ? '#00ff88' : '#ff5252' }}
                    >
                      {trade.action}
                    </span>
                  </td>
                  <td>{trade.quantity}</td>
                  <td>${trade.price.toFixed(2)}</td>
                  <td>${trade.total_amount.toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

export default TradePanel;
EOF

# Create src/components/AutoTradingPanel.js
cat > src/components/AutoTradingPanel.js << 'EOF'
import React, { useState, useEffect } from 'react';
import api from '../utils/api';
import './Components.css';

const AutoTradingPanel = () => {
  const [config, setConfig] = useState({
    enabled: false,
    confidence_threshold: 0.7,
    max_trade_size: 5
  });
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      const response = await api.get('/auto-trading/config');
      setConfig(response.data);
    } catch (error) {
      console.error('Error fetching config:', error);
    }
  };

  const handleSave = async () => {
    setLoading(true);
    setMessage('');
    try {
      await api.put('/auto-trading/config', config);
      setMessage('Settings saved successfully!');
      setTimeout(() => setMessage(''), 3000);
    } catch (error) {
      setMessage('Error saving settings');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="panel">
      <h2 className="panel-title">Auto Trading</h2>
      <div className="auto-trading-content">
        <div className="toggle-container">
          <label className="toggle-label">
            <input
              type="checkbox"
              checked={config.enabled}
              onChange={(e) => setConfig({ ...config, enabled: e.target.checked })}
              className="toggle-input"
            />
            <span className="toggle-slider" />
            <span className="toggle-text">
              {config.enabled ? 'Enabled' : 'Disabled'}
            </span>
          </label>
        </div>

        <div className="slider-container">
          <label className="slider-label">
            Confidence Threshold: {(config.confidence_threshold * 100).toFixed(0)}%
          </label>
          <input
            type="range"
            min="0.5"
            max="1.0"
            step="0.05"
            value={config.confidence_threshold}
            onChange={(e) => setConfig({ ...config, confidence_threshold: parseFloat(e.target.value) })}
            className="slider"
          />
        </div>

        <div className="input-container">
          <label className="input-label">Max Trade Size (shares)</label>
          <input
            type="number"
            min="1"
            max="100"
            value={config.max_trade_size}
            onChange={(e) => setConfig({ ...config, max_trade_size: parseInt(e.target.value) })}
            className="number-input"
          />
        </div>

        <button 
          onClick={handleSave} 
          disabled={loading}
          className="save-button"
        >
          {loading ? 'Saving...' : 'Save Settings'}
        </button>

        {message && (
          <div className={`message ${message.includes('Error') ? 'error' : 'success'}`}>
            {message}
          </div>
        )}
      </div>
    </div>
  );
};

export default AutoTradingPanel;
EOF

# Create src/components/ControlPanel.js
cat > src/components/ControlPanel.js << 'EOF'
import React, { useState } from 'react';
import api from '../utils/api';
import './Components.css';

const ControlPanel = ({ ticker, onTradeComplete }) => {
  const [quantity, setQuantity] = useState(1);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const executeTrade = async (action) => {
    setLoading(true);
    setMessage('');
    try {
      await api.post('/trade', {
        ticker_symbol: ticker,
        action,
        quantity: parseInt(quantity)
      });
      setMessage(`${action} order executed successfully!`);
      setTimeout(() => setMessage(''), 3000);
      if (onTradeComplete) onTradeComplete();
    } catch (error) {
      setMessage(error.response?.data?.detail || `Error executing ${action}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="panel">
      <h2 className="panel-title">Trade Control</h2>
      <div className="control-content">
        <div className="quantity-container">
          <label className="quantity-label">Quantity</label>
          <input
            type="number"
            min="1"
            value={quantity}
            onChange={(e) => setQuantity(e.target.value)}
            className="quantity-input"
          />
        </div>

        <div className="trade-buttons">
          <button
            onClick={() => executeTrade('BUY')}
            disabled={loading}
            className="trade-button buy-button"
          >
            BUY
          </button>
          <button
            onClick={() => executeTrade('SELL')}
            disabled={loading}
            className="trade-button sell-button"
          >
            SELL
          </button>
        </div>

        {message && (
          <div className={`message ${message.includes('Error') ? 'error' : 'success'}`}>
            {message}
          </div>
        )}
      </div>
    </div>
  );
};

export default ControlPanel;
EOF

# Create src/components/Components.css
cat > src/components/Components.css << 'EOF'
.panel {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
  padding: 20px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  transition: transform 0.3s ease, box-shadow 0.3s ease;
}

.panel:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.4);
}

.panel-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 15px;
  color: #00d4ff;
}

/* Indicators */
.indicators-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
}

.indicator-item {
  background: rgba(255, 255, 255, 0.03);
  padding: 12px;
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.05);
}

.indicator-label {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
  margin-bottom: 5px;
}

.indicator-value {
  font-size: 18px;
  font-weight: 600;
  color: #00d4ff;
}

/* Signal Panel */
.signal-content {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.signal-action {
  font-size: 32px;
  font-weight: 700;
  text-align: center;
  padding: 15px;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
}

.confidence-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.confidence-label {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.7);
}

.confidence-bar {
  height: 12px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 6px;
  overflow: hidden;
}

.confidence-fill {
  height: 100%;
  transition: width 0.5s ease;
  border-radius: 6px;
}

.signal-reason {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.8);
  line-height: 1.5;
  padding: 12px;
  background: rgba(255, 255, 255, 0.03);
  border-radius: 10px;
}

/* Portfolio */
.portfolio-cards {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
  margin-bottom: 20px;
}

.portfolio-card {
  background: rgba(255, 255, 255, 0.03);
  padding: 15px;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.05);
}

.card-label {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
  margin-bottom: 5px;
}

.card-value {
  font-size: 20px;
  font-weight: 700;
}

.positions-title {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 10px;
  color: rgba(255, 255, 255, 0.8);
}

.positions-list {
  max-height: 200px;
  overflow-y: auto;
}

.position-item {
  background: rgba(255, 255, 255, 0.03);
  padding: 12px;
  border-radius: 10px;
  margin-bottom: 8px;
  border: 1px solid rgba(255, 255, 255, 0.05);
}

.position-symbol {
  font-size: 16px;
  font-weight: 600;
  color: #00d4ff;
  margin-bottom: 5px;
}

.position-details {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.7);
}

/* Trade Panel */
.trades-container {
  max-height: 300px;
  overflow-y: auto;
}

.trades-table {
  width: 100%;
  border-collapse: collapse;
}

.trades-table th {
  text-align: left;
  padding: 10px;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.6);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.trades-table td {
  padding: 10px;
  font-size: 13px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

.trade-action {
  font-weight: 600;
}

.empty-state {
  text-align: center;
  padding: 40px;
  color: rgba(255, 255, 255, 0.4);
}

/* Auto Trading */
.auto-trading-content {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.toggle-container {
  display: flex;
  justify-content: center;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
}

.toggle-input {
  display: none;
}

.toggle-slider {
  width: 60px;
  height: 30px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 15px;
  position: relative;
  transition: background 0.3s ease;
}

.toggle-slider::before {
  content: '';
  position: absolute;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: #fff;
  top: 2px;
  left: 2px;
  transition: transform 0.3s ease;
}

.toggle-input:checked + .toggle-slider {
  background: #00d4ff;
}

.toggle-input:checked + .toggle-slider::before {
  transform: translateX(30px);
}

.toggle-text {
  font-size: 16px;
  font-weight: 600;
}

.slider-container,
.input-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.slider-label,
.input-label {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.7);
}

.slider {
  width: 100%;
  height: 8px;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.1);
  outline: none;
  -webkit-appearance: none;
}

.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #00d4ff;
  cursor: pointer;
}

.slider::-moz-range-thumb {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: #00d4ff;
  cursor: pointer;
  border: none;
}

.number-input {
  padding: 12px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #fff;
  font-size: 16px;
}

.number-input:focus {
  outline: none;
  border-color: #00d4ff;
}

.save-button {
  padding: 12px;
  background: linear-gradient(135deg, #00d4ff 0%, #0099ff 100%);
  border: none;
  border-radius: 10px;
  color: #fff;
  font-size: 16px;
  font-weight: 600;
  cursor: pointer;
  transition: transform 0.2s ease;
}

.save-button:hover:not(:disabled) {
  transform: translateY(-2px);
}

.save-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

/* Control Panel */
.control-content {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.quantity-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.quantity-label {
  font-size: 14px;
  color: rgba(255, 255, 255, 0.7);
}

.quantity-input {
  padding: 12px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #fff;
  font-size: 18px;
  text-align: center;
}

.quantity-input:focus {
  outline: none;
  border-color: #00d4ff;
}

.trade-buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.trade-button {
  padding: 16px;
  border: none;
  border-radius: 10px;
  font-size: 18px;
  font-weight: 700;
  cursor: pointer;
  transition: transform 0.2s ease, box-shadow 0.3s ease;
}

.trade-button:hover:not(:disabled) {
  transform: translateY(-2px);
}

.trade-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.buy-button {
  background: linear-gradient(135deg, #00ff88 0%, #00cc6a 100%);
  color: #0a0e27;
}

.buy-button:hover:not(:disabled) {
  box-shadow: 0 8px 20px rgba(0, 255, 136, 0.3);
}

.sell-button {
  background: linear-gradient(135deg, #ff5252 0%, #cc4242 100%);
  color: #fff;
}

.sell-button:hover:not(:disabled) {
  box-shadow: 0 8px 20px rgba(255, 82, 82, 0.3);
}

.message {
  padding: 12px;
  border-radius: 10px;
  text-align: center;
  font-size: 14px;
  animation: fadeIn 0.3s ease;
}

.message.success {
  background: rgba(0, 255, 136, 0.1);
  border: 1px solid rgba(0, 255, 136, 0.3);
  color: #00ff88;
}

.message.error {
  background: rgba(255, 82, 82, 0.1);
  border: 1px solid rgba(255, 82, 82, 0.3);
  color: #ff5252;
}

@media (max-width: 768px) {
  .indicators-grid,
  .portfolio-cards {
    grid-template-columns: 1fr;
  }
  
  .trades-table {
    font-size: 11px;
  }
  
  .trades-table th,
  .trades-table td {
    padding: 6px;
  }
}
EOF

# Create src/pages/Dashboard.js
cat > src/pages/Dashboard.js << 'EOF'
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

  useEffect(() => {
    fetchTickers();
    const interval = setInterval(() => {
      fetchData();
    }, 5000); // Auto-refresh every 5 seconds
    return () => clearInterval(interval);
  }, [selectedTicker]);

  const fetchTickers = async () => {
    try {
      const response = await api.get('/tickers');
      setTickers(response.data);
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
            onChange={(e) => setSelectedTicker(e.target.value)}
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

      <div className="dashboard-grid fade-in">
        <div className="grid-item chart-area">
          <PriceChart prices={prices} />
        </div>
        <div className="grid-item indicators-area">
          <IndicatorPanel indicators={indicators} />
        </div>
        <div className="grid-item signal-area">
          <SignalPanel signal={signal} />
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
    </div>
  );
};

export default Dashboard;
EOF

# Create src/pages/Dashboard.css
cat > src/pages/Dashboard.css << 'EOF'
.dashboard {
  min-height: 100vh;
  padding: 20px;
  background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 30px;
  padding: 20px;
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 16px;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 20px;
}

.dashboard-title {
  font-size: 28px;
  font-weight: 700;
  background: linear-gradient(135deg, #00d4ff 0%, #0099ff 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.ticker-selector {
  padding: 10px 16px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  color: #fff;
  font-size: 15px;
  cursor: pointer;
  transition: all 0.3s ease;
  min-width: 200px;
}

.ticker-selector:focus {
  outline: none;
  border-color: #00d4ff;
  background: rgba(255, 255, 255, 0.08);
}

.header-right {
  display: flex;
  align-items: center;
  gap: 15px;
}

.user-info {
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
}

.logout-button {
  padding: 10px 20px;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 10px;
  color: #fff;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.logout-button:hover {
  background: rgba(255, 255, 255, 0.15);
  border-color: #ff5252;
  color: #ff5252;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  grid-template-rows: repeat(3, minmax(300px, auto));
  gap: 20px;
}

.grid-item {
  animation: fadeIn 0.5s ease-out;
}

.chart-area {
  grid-column: 1 / 9;
  grid-row: 1 / 2;
}

.indicators-area {
  grid-column: 9 / 13;
  grid-row: 1 / 2;
}

.signal-area {
  grid-column: 1 / 5;
  grid-row: 2 / 3;
}

.portfolio-area {
  grid-column: 5 / 9;
  grid-row: 2 / 3;
}

.control-area {
  grid-column: 9 / 13;
  grid-row: 2 / 3;
}

.trades-area {
  grid-column: 1 / 7;
  grid-row: 3 / 4;
}

.auto-area {
  grid-column: 7 / 13;
  grid-row: 3 / 4;
}

/* Responsive Design */
@media (max-width: 1400px) {
  .dashboard-grid {
    grid-template-columns: repeat(8, 1fr);
  }

  .chart-area {
    grid-column: 1 / 6;
  }

  .indicators-area {
    grid-column: 6 / 9;
  }

  .signal-area {
    grid-column: 1 / 5;
  }

  .portfolio-area {
    grid-column: 5 / 9;
  }

  .control-area {
    grid-column: 1 / 9;
    grid-row: 3 / 4;
  }

  .trades-area {
    grid-column: 1 / 5;
    grid-row: 4 / 5;
  }

  .auto-area {
    grid-column: 5 / 9;
    grid-row: 4 / 5;
  }
}

@media (max-width: 1024px) {
  .dashboard-header {
    flex-direction: column;
    gap: 15px;
  }

  .header-left {
    flex-direction: column;
    width: 100%;
  }

  .ticker-selector {
    width: 100%;
  }

  .dashboard-grid {
    grid-template-columns: 1fr;
    grid-template-rows: auto;
  }

  .grid-item {
    grid-column: 1 / -1 !important;
    grid-row: auto !important;
  }
}

@media (max-width: 768px) {
  .dashboard {
    padding: 10px;
  }

  .dashboard-header {
    padding: 15px;
  }

  .dashboard-title {
    font-size: 22px;
  }

  .dashboard-grid {
    gap: 15px;
  }
}
EOF

# Create src/App.js
cat > src/App.js << 'EOF'
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './contexts/AuthContext';
import LoginForm from './pages/LoginForm';
import RegisterForm from './pages/RegisterForm';
import Dashboard from './pages/Dashboard';
import ProtectedRoute from './components/ProtectedRoute';

function App() {
  return (
    <Router>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginForm />} />
          <Route path="/register" element={<RegisterForm />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </AuthProvider>
    </Router>
  );
}

export default App;
EOF

# Create nginx.conf
cat > nginx/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Frontend routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API proxy to backend
    location /api/ {
        proxy_pass http://backend:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create Dockerfile for frontend
cat > Dockerfile << 'EOF'
# Build stage
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine

COPY --from=build /app/build /usr/share/nginx/html
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
node_modules
build
.git
.gitignore
README.md
.env
EOF

# Update docker-compose.yml in backend
cd ../backend
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: trading_user
      POSTGRES_PASSWORD: trading_pass
      POSTGRES_DB: trading_db
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U trading_user"]
      interval: 5s
      timeout: 5s
      retries: 5

  backend:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://trading_user:trading_pass@postgres:5432/trading_db
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-change-in-production-min-32-chars}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./app:/app/app
      - ./alembic:/app/alembic

  scheduler:
    build:
      context: .
      dockerfile: Dockerfile.scheduler
    environment:
      DATABASE_URL: postgresql://trading_user:trading_pass@postgres:5432/trading_db
      SECRET_KEY: ${SECRET_KEY:-your-secret-key-change-in-production-min-32-chars}
      ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
    depends_on:
      postgres:
        condition: service_healthy
      backend:
        condition: service_started
    volumes:
      - ./app:/app/app
      - ./scheduler:/app/scheduler

  frontend:
    build: ../frontend
    ports:
      - "3000:80"
    depends_on:
      - backend
    environment:
      - NODE_ENV=production

volumes:
  postgres_data:
EOF

cd ..

echo ""
echo "✅ Frontend generation complete!"
echo ""
echo "📁 Structure created:"
echo "frontend/"
echo "├── src/"
echo "│   ├── components/         # All 7 components"
echo "│   ├── contexts/          # AuthContext with JWT"
echo "│   ├── pages/             # Login, Register, Dashboard"
echo "│   ├── utils/             # API with axios interceptors"
echo "│   ├── App.js             # Routes & Protected Routes"
echo "│   └── index.css          # Dark theme styles"
echo "├── nginx/"
echo "│   └── nginx.conf         # API proxy config"
echo "├── Dockerfile             # Multi-stage build"
echo "└── package.json           # React 18 dependencies"
echo ""
echo "🚀 To start the complete application:"
echo "   cd backend"
echo "   docker-compose up --build"
echo ""
echo "🌐 Access points:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8000"
echo "   Swagger:   http://localhost:8000/docs"
echo ""
echo "🎨 Features:"
echo "   ✓ Dark theme (#0a0e27)"
echo "   ✓ Glassmorphism effects"
echo "   ✓ 7-component responsive grid"
echo "   ✓ Auto-refresh every 5 seconds"
echo "   ✓ JWT authentication with localStorage"
echo "   ✓ Axios interceptors for auth"
echo "   ✓ Protected routes"
echo "   ✓ Green/red P&L indicators"
echo ""