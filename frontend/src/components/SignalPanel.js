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
