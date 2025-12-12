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
