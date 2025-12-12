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
