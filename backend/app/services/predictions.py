import httpx
from typing import Dict
from app.core.config import settings
from app.services.indicators import get_technical_indicators
from sqlalchemy.orm import Session


async def get_claude_prediction(indicators: Dict[str, float], ticker_symbol: str) -> Dict[str, any]:
    """Get trading prediction from Claude API"""
    if not settings.ANTHROPIC_API_KEY:
        return rule_based_fallback(indicators)
    
    try:
        prompt = f"""Analyze these technical indicators for {ticker_symbol} and provide a trading recommendation:

Technical Indicators:
- SMA(20): {indicators.get('sma_20', 'N/A')}
- SMA(50): {indicators.get('sma_50', 'N/A')}
- EMA(12): {indicators.get('ema_12', 'N/A')}
- EMA(26): {indicators.get('ema_26', 'N/A')}
- RSI(14): {indicators.get('rsi_14', 'N/A')}
- MACD: {indicators.get('macd', 'N/A')}
- MACD Signal: {indicators.get('macd_signal', 'N/A')}
- MACD Histogram: {indicators.get('macd_histogram', 'N/A')}
- Bollinger Upper: {indicators.get('bollinger_upper', 'N/A')}
- Bollinger Middle: {indicators.get('bollinger_middle', 'N/A')}
- Bollinger Lower: {indicators.get('bollinger_lower', 'N/A')}
- Volatility: {indicators.get('volatility', 'N/A')}

Provide your recommendation in exactly this JSON format:
{{"action": "BUY|SELL|HOLD", "confidence": 0.0-1.0, "reason": "brief explanation"}}"""

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": settings.ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                },
                json={
                    "model": "claude-sonnet-4-20250514",
                    "max_tokens": 1000,
                    "messages": [
                        {"role": "user", "content": prompt}
                    ]
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                content = data.get("content", [])
                if content and len(content) > 0:
                    text = content[0].get("text", "")
                    # Parse JSON from response
                    import json
                    # Extract JSON from potential markdown or text
                    if "```json" in text:
                        text = text.split("```json")[1].split("```")[0].strip()
                    elif "```" in text:
                        text = text.split("```")[1].split("```")[0].strip()
                    
                    result = json.loads(text.strip())
                    return {
                        "action": result.get("action", "HOLD").upper(),
                        "confidence": float(result.get("confidence", 0.5)),
                        "reason": result.get("reason", "AI prediction")
                    }
    except Exception as e:
        print(f"Claude API error: {e}")
    
    return rule_based_fallback(indicators)


def rule_based_fallback(indicators: Dict[str, float]) -> Dict[str, any]:
    """Rule-based trading signal fallback"""
    rsi = indicators.get('rsi_14')
    macd_histogram = indicators.get('macd_histogram')
    sma_20 = indicators.get('sma_20')
    sma_50 = indicators.get('sma_50')
    
    action = "HOLD"
    confidence = 0.5
    reason = "Insufficient data for clear signal"
    
    # RSI-based signals
    if rsi is not None:
        if rsi < 30:
            action = "BUY"
            confidence = 0.7
            reason = f"RSI ({rsi:.2f}) indicates oversold conditions"
        elif rsi > 70:
            action = "SELL"
            confidence = 0.7
            reason = f"RSI ({rsi:.2f}) indicates overbought conditions"
    
    # MACD confirmation
    if macd_histogram is not None and macd_histogram > 0 and action == "BUY":
        confidence = min(0.85, confidence + 0.15)
        reason += " with positive MACD momentum"
    elif macd_histogram is not None and macd_histogram < 0 and action == "SELL":
        confidence = min(0.85, confidence + 0.15)
        reason += " with negative MACD momentum"
    
    # Moving average crossover
    if sma_20 is not None and sma_50 is not None:
        if sma_20 > sma_50 and action == "BUY":
            confidence = min(0.9, confidence + 0.1)
            reason += " and bullish MA crossover"
        elif sma_20 < sma_50 and action == "SELL":
            confidence = min(0.9, confidence + 0.1)
            reason += " and bearish MA crossover"
    
    return {
        "action": action,
        "confidence": confidence,
        "reason": reason
    }


async def get_trading_signal(db: Session, ticker_id: int, ticker_symbol: str) -> Dict[str, any]:
    """Get trading signal for a ticker"""
    indicators = get_technical_indicators(db, ticker_id)
    return await get_claude_prediction(indicators, ticker_symbol)
