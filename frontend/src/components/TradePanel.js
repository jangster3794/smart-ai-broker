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
