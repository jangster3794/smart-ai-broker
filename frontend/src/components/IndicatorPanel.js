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
