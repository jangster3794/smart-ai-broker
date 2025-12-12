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
