//+------------------------------------------------------------------+
//|                     Fimathe_PCM_Pro_v3.mq5                        |
//|              EXPERT ADVISOR PROFISSIONAL - FIMATHE PCM             |
//|         Automação Completa para Operação de Alto Desempenho       |
//|                     Desenvolvido para Igor Trader                  |
//+------------------------------------------------------------------+
#property copyright "Igor Trader - Fimathe PCM Pro"
#property link "https://fimathe.com"
#property version "3.00"
#property strict

// ==================== CONFIGURAÇÕES GERAIS ====================
input string    InpEAName           = "Fimathe_PCM_Pro";       // Nome do EA
input int       InpMagicNumber      = 20250124;                // Magic number único

// ==================== SÍMBOLOS E TIMEFRAMES ====================
input string    InpSymbols          = "EURUSD,GBPUSD,NZDUSD"; // Símbolos separados por vírgula
input ENUM_TIMEFRAMES InpTimeframe  = PERIOD_M5;               // Timeframe
input int       InpCheckInterval    = 5;                       // Intervalo de checagem (segundos)

// ==================== CONFIGURAÇÃO FIMATHE PCM ====================
input int       InpFirstCandles     = 4;                       // Primeiras velas para CA
input double    InpChannelPercent   = 0.50;                    // % de desvio para canal (0.50 = 0.5%)
input string    InpEntryCriteria    = "SMART";                 // BREAK, TOUCH, ou SMART
input bool      InpAutoDirection    = true;                    // Detectar direção automática
input int       InpMinSpread        = 5;                       // Spread mínimo em pontos

// ==================== GERENCIAMENTO DE RISCO ====================
input double    InpRiskPercent      = 2.0;                     // Risco por trade em % do capital
input double    InpMaxRiskDay       = 5.0;                     // Risco máximo diário em % do capital
input bool      InpAutoLot          = true;                    // Calcular lote automaticamente
input double    InpFixedLot         = 0.1;                     // Lote fixo se não auto
input double    InpMaxLot           = 1.0;                     // Lote máximo permitido

// ==================== STOP LOSS E TAKE PROFIT ====================
input int       InpStopLossPoints   = 50;                      // Stop Loss em pontos
input int       InpTakeProfitPoints = 100;                     // Take Profit em pontos
input double    InpRiskRewardRatio  = 2.0;                     // Razão Risco/Recompensa

// ==================== GERENCIAMENTO DE POSIÇÃO ====================
input bool      InpUseTrailingStop  = true;                    // Trailing stop ativo
input int       InpTrailingPoints   = 30;                      // Distância trailing
input bool      InpUseBreakEven     = true;                    // Break even ativo
input int       InpBreakEvenPoints  = 20;                      // Distância break even
input bool      InpUsePartialTake   = true;                    // Venda parcial em lucro
input double    InpPartialPercent   = 50.0;                    // % de posição para vender em TP50%
input int       InpPartialTakeProfit= 50;                      // Pontos de TP para venda parcial

// ==================== FILTROS E PROTEÇÕES ====================
input int       InpStartHour        = 9;                       // Hora início operações
input int       InpEndHour          = 17;                      // Hora fim operações
input int       InpMaxTradesDay     = 20;                      // Máximo trades por dia
input int       InpMaxTradesHour    = 3;                       // Máximo trades por hora
input int       InpMinTimeBetweenTrades = 60;                  // Tempo mínimo entre trades (segundos)
input bool      InpUseNewsFilter    = false;                   // Filtro de notícias econômicas
input int       InpMinVolatility    = 5;                       // Volatilidade mínima (pips)
input int       InpMaxVolatility    = 500;                     // Volatilidade máxima (pips)

// ==================== ALERTAS E NOTIFICAÇÕES ====================
input bool      InpAlertSound       = true;                    // Som de alerta
input bool      InpAlertEmail       = false;                   // Email alerta
input string    InpEmailAddress     = "seu@email.com";         // Email
input bool      InpAlertNotification= true;                    // Push notification
input bool      InpPrintLog         = true;                    // Log no expert log

// ==================== VARIÁVEIS GLOBAIS ====================
struct STrade {
    int magicNumber;
    ulong ticket;
    ENUM_ORDER_TYPE type;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double partialTakeProfit;
    datetime entryTime;
    double volume;
    string symbol;
};

struct SSymbolData {
    string symbol;
    double highChannel;
    double lowChannel;
    double channelSpread;
    int lastSignal;  // 1=BUY, -1=SELL, 0=NONE
    datetime lastSignalTime;
    double volatility;
};

int g_TradeCountDay       = 0;
int g_TradeCountHour      = 0;
datetime g_LastTradeTime  = 0;
datetime g_StartDay       = 0;
datetime g_StartHour      = 0;
double g_PnlDay           = 0;
double g_MaxDrawdown      = 0;
double g_EquityStart      = 0;
int g_ActiveTrades        = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    g_EquityStart = AccountInfoDouble(ACCOUNT_EQUITY);
    g_StartDay = TimeCurrent();
    g_StartHour = TimeCurrent();
    
    PrintInitInfo();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if(InpPrintLog) Print("[" + InpEAName + "] Desligado. Razão: " + IntegerToString(reason));
    Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Reset contadores diários
    if((TimeCurrent() - g_StartDay) >= 86400) {
        g_TradeCountDay = 0;
        g_PnlDay = 0;
        g_StartDay = TimeCurrent();
    }
    
    // Reset contadores horários
    if((TimeCurrent() - g_StartHour) >= 3600) {
        g_TradeCountHour = 0;
        g_StartHour = TimeCurrent();
    }
    
    // Verificar filtros gerais
    if(!IsTimeAllowed()) return;
    if(g_TradeCountDay >= InpMaxTradesDay) return;
    if(g_TradeCountHour >= InpMaxTradesHour) return;
    if(g_PnlDay <= -(AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxRiskDay / 100.0))) return;
    
    // Processar símbolos
    ProcessSymbols();
    
    // Gerenciar posições abertas
    ManageOpenPositions();
    
    // Atualizar painel
    UpdatePanel();
}

//+------------------------------------------------------------------+
//| Process all symbols                                              |
//+------------------------------------------------------------------+
void ProcessSymbols() {
    string symbols[];
    StringSplit(InpSymbols, ',', symbols);
    
    for(int i = 0; i < ArraySize(symbols); i++) {
        string symbol = StringTrim(symbols[i]);
        if(StringLen(symbol) == 0) continue;
        
        SSymbolData data = AnalyzeSymbol(symbol);
        
        // Verificar sinais
        if(data.lastSignal == 1 && !HasOpenPosition(symbol, ORDER_TYPE_BUY)) {
            ExecuteBuyTrade(symbol, data);
        }
        else if(data.lastSignal == -1 && !HasOpenPosition(symbol, ORDER_TYPE_SELL)) {
            ExecuteSellTrade(symbol, data);
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze symbol and detect signals - FIMATHE PCM CORRIGIDO v4      |
//+------------------------------------------------------------------+
SSymbolData AnalyzeSymbol(string symbol) {
    SSymbolData data = {};
    data.symbol = symbol;
    data.lastSignal = 0;
    
    // Selecionar símbolo
    if(!SymbolSelect(symbol, true)) {
        if(InpPrintLog) Print("[ERRO] Não foi possível selecionar " + symbol);
        return data;
    }
    
    // ==================== CÁLCULO CORRETO DO CANAL DE ABERTURA (CA) ====================
    // CA = High máximo E Low mínimo das primeiras N velas (padrão 4)
    double highChannel = DBL_MIN;
    double lowChannel = DBL_MAX;
    
    for(int i = InpFirstCandles; i >= 1; i--) {
        double h = iHigh(symbol, InpTimeframe, i);
        double l = iLow(symbol, InpTimeframe, i);
        
        if(h > highChannel) highChannel = h;  // HIGH máximo
        if(l < lowChannel) lowChannel = l;   // LOW mínimo
    }
    
    data.highChannel = highChannel;
    data.lowChannel = lowChannel;
    data.channelSpread = highChannel - lowChannel;
    
    // ==================== CÁLCULO DE VOLATILIDADE ====================
    double volatility = 0;
    for(int i = 1; i <= 14; i++) {
        volatility += MathAbs(iHigh(symbol, InpTimeframe, i) - iLow(symbol, InpTimeframe, i));
    }
    data.volatility = volatility / 14.0;
    
    // ==================== VALIDAÇÕES ====================
    if(data.volatility < InpMinVolatility || data.volatility > InpMaxVolatility) {
        if(InpPrintLog) Print("[VOLATILIDADE] " + symbol + " fora do range: " + DoubleToString(data.volatility, 2));
        return data;
    }
    
    // Validar spread
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double spread = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(spread > (InpMinSpread * 2)) {
        if(InpPrintLog) Print("[SPREAD] " + symbol + " alto: " + DoubleToString(spread, 1) + " pts");
        return data;
    }
    
    // ==================== GERAÇÃO DE SINAIS FIMATHE PCM CORRETO ====================
    double close0 = iClose(symbol, InpTimeframe, 0);
    double close1 = iClose(symbol, InpTimeframe, 1);
    double close2 = iClose(symbol, InpTimeframe, 2);
    double high1 = iHigh(symbol, InpTimeframe, 1);
    double low1 = iLow(symbol, InpTimeframe, 1);
    
    double midChannel = (highChannel + lowChannel) / 2.0;  // Zona 50%
    
    // ==================== MODO: ENTRADA INTELIGENTE (SMART PCM) ====================
    // Rompimento + retorno aos 50% + confirmação
    string criteria = StringUpper(InpEntryCriteria);
    
    if(criteria == "SMART") {
        // BUY: Rompimento para cima + retorno aos 50% + confirmação
        if(close1 > highChannel && close2 <= highChannel && close2 >= midChannel) {
            if(close0 > midChannel && close0 <= highChannel + ((highChannel - lowChannel) * 0.2)) {
                data.lastSignal = 1;
                if(InpPrintLog) Print("[PCM BUY SMART] " + symbol + " - Rompeu CA + retornou 50% + confirmação");
            }
        }
        // SELL: Rompimento para baixo + retorno aos 50% + confirmação  
        else if(close1 < lowChannel && close2 >= lowChannel && close2 <= midChannel) {
            if(close0 < midChannel && close0 >= lowChannel - ((highChannel - lowChannel) * 0.2)) {
                data.lastSignal = -1;
                if(InpPrintLog) Print("[PCM SELL SMART] " + symbol + " - Rompeu CA + retornou 50% + confirmação");
            }
        }
    }
    // ==================== MODO BREAK: SIMPLES ROMPIMENTO ====================
    else if(criteria == "BREAK") {
        if(close0 > highChannel && close1 <= highChannel) {
            data.lastSignal = 1;
            if(InpPrintLog) Print("[PCM BUY BREAK] " + symbol + " - Rompimento simples CA superior");
        }
        else if(close0 < lowChannel && close1 >= lowChannel) {
            data.lastSignal = -1;
            if(InpPrintLog) Print("[PCM SELL BREAK] " + symbol + " - Rompimento simples CA inferior");
        }
    }
    // ==================== MODO TOUCH: TOQUE + ROMPIMENTO ====================
    else if(criteria == "TOUCH") {
        if(low1 >= lowChannel && close0 > highChannel) {
            data.lastSignal = 1;
            if(InpPrintLog) Print("[PCM BUY TOUCH] " + symbol + " - Toque+rompimento CA");
        }
        else if(high1 <= highChannel && close0 < lowChannel) {
            data.lastSignal = -1;
            if(InpPrintLog) Print("[PCM SELL TOUCH] " + symbol + " - Toque+rompimento CA");
        }
    }
    
    return data;
}

//+------------------------------------------------------------------+
//| Execute Buy Trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade(string symbol, SSymbolData &data) {
    // ==================== VALIDAÇÕES CRÍTICAS ====================
    if((TimeCurrent() - g_LastTradeTime) < InpMinTimeBetweenTrades) return;
    if(g_TradeCountHour >= InpMaxTradesHour) return;
    if(g_TradeCountDay >= InpMaxTradesDay) return;
    if(g_PnlDay <= -(AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxRiskDay / 100.0))) return;
    
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Validar spread
    double spreadPoints = (ask - bid) / point;
    if(spreadPoints > (InpMinSpread * 2)) {
        if(InpPrintLog) Print("[SPREAD ALTO] " + symbol + " - Operação cancelada");
        return;
    }
    
    double lots = CalculateLotSize(symbol);
    // ✅ Stop Loss CORRETO: Abaixo do canal de abertura (proteção real)
    double stopLoss = data.lowChannel - (InpStopLossPoints * point);
    // Take Profit padrão = 2x do risco (RR 2:1)
    double riskPoints = (ask - stopLoss) / point;
    double takeProfit = ask + (riskPoints * InpRiskRewardRatio * point);
    
    // Enviar ordem
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.magic = InpMagicNumber;
    request.comment = "Fimathe PCM BUY";
    request.deviation = 50;
    request.type_filling = ORDER_FILLING_IOC;
    
    if(OrderSend(&request, &result)) {
        g_TradeCountDay++;
        g_TradeCountHour++;
        g_LastTradeTime = TimeCurrent();
        g_ActiveTrades++;
        
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        SendAlert("✅ BUY " + symbol + " | Entrada: " + DoubleToString(ask, digits) + 
                 " | SL: " + DoubleToString(stopLoss, digits) + " | TP: " + DoubleToString(takeProfit, digits));
    }
    else {
        SendAlert("❌ ERRO BUY " + symbol + " | Código: " + IntegerToString(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Execute Sell Trade                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade(string symbol, SSymbolData &data) {
    // ==================== VALIDAÇÕES CRÍTICAS ====================
    if((TimeCurrent() - g_LastTradeTime) < InpMinTimeBetweenTrades) return;
    if(g_TradeCountHour >= InpMaxTradesHour) return;
    if(g_TradeCountDay >= InpMaxTradesDay) return;
    if(g_PnlDay <= -(AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxRiskDay / 100.0))) return;
    
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Validar spread
    double spreadPoints = (ask - bid) / point;
    if(spreadPoints > (InpMinSpread * 2)) {
        if(InpPrintLog) Print("[SPREAD ALTO] " + symbol + " - Operação cancelada");
        return;
    }
    
    double lots = CalculateLotSize(symbol);
    // ✅ Stop Loss CORRETO: Acima do canal de abertura (proteção real)
    double stopLoss = data.highChannel + (InpStopLossPoints * point);
    // Take Profit padrão = 2x do risco (RR 2:1)
    double riskPoints = (stopLoss - bid) / point;
    double takeProfit = bid - (riskPoints * InpRiskRewardRatio * point);
    
    // Enviar ordem
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.magic = InpMagicNumber;
    request.comment = "Fimathe PCM SELL";
    request.deviation = 50;
    request.type_filling = ORDER_FILLING_IOC;
    
    if(OrderSend(&request, &result)) {
        g_TradeCountDay++;
        g_TradeCountHour++;
        g_LastTradeTime = TimeCurrent();
        g_ActiveTrades++;
        
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        SendAlert("✅ SELL " + symbol + " | Entrada: " + DoubleToString(bid, digits) + 
                 " | SL: " + DoubleToString(stopLoss, digits) + " | TP: " + DoubleToString(takeProfit, digits));
    }
    else {
        SendAlert("❌ ERRO SELL " + symbol + " | Código: " + IntegerToString(result.retcode));
    }
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
    g_ActiveTrades = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            g_ActiveTrades++;
            
            if(InpUseTrailingStop) {
                ApplyTrailingStop(ticket);
            }
            
            if(InpUseBreakEven) {
                ApplyBreakEven(ticket);
            }
            
            if(InpUsePartialTake) {
                ApplyPartialTake(ticket);
            }
            
            // Atualizar PnL
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit > 0) g_PnlDay += profit;
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop - VERSÃO PCM SURFADA REAL                   |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    string symbol = PositionGetString(POSITION_SYMBOL);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    double newSL = 0;
    
    if(type == POSITION_TYPE_BUY) {
        // Surfada real: Move SL a cada novo mínimo que sobe
        double distanceFromEntry = (bid - entry) / point;
        newSL = entry + ((distanceFromEntry / 2.0) * point);
        
        if(newSL > sl + (InpTrailingPoints * point)) {
            ModifyPosition(ticket, newSL, tp);
            if(InpPrintLog) Print("[SURFADA BUY] " + symbol + " - SL movido para: " + DoubleToString(newSL, digits));
        }
    }
    else {
        // SELL: Surfada movendo SL para cima
        double distanceFromEntry = (entry - ask) / point;
        newSL = entry - ((distanceFromEntry / 2.0) * point);
        
        if(newSL < sl - (InpTrailingPoints * point)) {
            ModifyPosition(ticket, newSL, tp);
            if(InpPrintLog) Print("[SURFADA SELL] " + symbol + " - SL movido para: " + DoubleToString(newSL, digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Break Even                                                 |
//+------------------------------------------------------------------+
void ApplyBreakEven(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    string symbol = PositionGetString(POSITION_SYMBOL);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(type == POSITION_TYPE_BUY) {
        if((bid - entry) >= (InpBreakEvenPoints * point) && sl < (entry + point)) {
            ModifyPosition(ticket, entry + point, tp);
        }
    }
    else {
        if((entry - ask) >= (InpBreakEvenPoints * point) && (sl > (entry - point) || sl == 0)) {
            ModifyPosition(ticket, entry - point, tp);
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Partial Take Profit                                        |
//+------------------------------------------------------------------+
void ApplyPartialTake(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    string symbol = PositionGetString(POSITION_SYMBOL);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    double tp = PositionGetDouble(POSITION_TP);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    double partialTP = entry + (InpPartialTakeProfit * point);
    
    if(type == POSITION_TYPE_BUY) {
        if(bid >= partialTP) {
            double partialVolume = volume * (InpPartialPercent / 100.0);
            ClosePartialPosition(ticket, partialVolume);
        }
    }
    else {
        partialTP = entry - (InpPartialTakeProfit * point);
        if(ask <= partialTP) {
            double partialVolume = volume * (InpPartialPercent / 100.0);
            ClosePartialPosition(ticket, partialVolume);
        }
    }
}

//+------------------------------------------------------------------+
//| Close Partial Position                                           |
//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double partialVolume) {
    if(!PositionSelectByTicket(ticket)) return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = NormalizeDouble(partialVolume, 2);
    request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = ticket;
    request.magic = InpMagicNumber;
    request.comment = "Fimathe PCM Partial Close";
    request.deviation = 50;
    request.type_filling = ORDER_FILLING_IOC;
    
    if(type == POSITION_TYPE_BUY) {
        request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
    } else {
        request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    }
    
    OrderSend(&request, &result);
}

//+------------------------------------------------------------------+
//| Modify Position                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double newSL, double newTP) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = newSL;
    request.tp = newTP;
    
    OrderSend(&request, &result);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size with Risk Management                          |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol) {
    if(!InpAutoLot) return InpFixedLot;
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (InpRiskPercent / 100.0);
    
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    double lots = (riskAmount / (InpStopLossPoints * tickValue)) * (tickSize / point);
    lots = NormalizeDouble(lots, 2);
    
    // Limites
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = MathMin(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
    double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    lots = MathFloor(lots / stepLot) * stepLot;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Check if has open position                                       |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol, ENUM_ORDER_TYPE type) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetString(POSITION_SYMBOL) == symbol &&
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == type) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if time is allowed                                         |
//+------------------------------------------------------------------+
bool IsTimeAllowed() {
    int hour = Hour();
    if(hour < InpStartHour || hour >= InpEndHour) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Send Alert                                                       |
//+------------------------------------------------------------------+
void SendAlert(string message) {
    if(InpAlertSound) Alert(message);
    if(InpAlertEmail) SendMail(InpEAName + " - Alert", message);
    if(InpAlertNotification) SendNotification(message);
    if(InpPrintLog) Print("[" + InpEAName + "] " + message);
}

//+------------------------------------------------------------------+
//| Update Panel Display                                             |
//+------------------------------------------------------------------+
void UpdatePanel() {
    string panelText = "";
    panelText += "╔════════════════════════════════════════════════════╗\n";
    panelText += "║         🤖 FIMATHE PCM PRO - STATUS OPERACIONAL   ║\n";
    panelText += "╠════════════════════════════════════════════════════╣\n";
    panelText += "║ Saldo: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    panelText += "║ Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    panelText += "║ Lucro Hoje: $" + DoubleToString(g_PnlDay, 2) + "\n";
    panelText += "║ Risco Hoje: " + DoubleToString((g_PnlDay / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0, 2) + "%\n";
    panelText += "║ ────────────────────────────────────────────────── ║\n";
    panelText += "║ Posições Abertas: " + IntegerToString(g_ActiveTrades) + "\n";
    panelText += "║ Trades Hoje: " + IntegerToString(g_TradeCountDay) + "/" + IntegerToString(InpMaxTradesDay) + "\n";
    panelText += "║ Trades Hora: " + IntegerToString(g_TradeCountHour) + "/" + IntegerToString(InpMaxTradesHour) + "\n";
    panelText += "║ ────────────────────────────────────────────────── ║\n";
    panelText += "║ Status: " + (IsTimeAllowed() ? "🟢 OPERANDO" : "🔴 FORA DO HORÁRIO") + "\n";
    panelText += "║ Horário: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
    panelText += "╚════════════════════════════════════════════════════╝\n";
    
    Comment(panelText);
}

//+------------------------------------------------------------------+
//| Print Initialization Info                                        |
//+------------------------------------------------------------------+
void PrintInitInfo() {
    Print("\n╔════════════════════════════════════════════════════╗");
    Print("║   FIMATHE PCM PRO v5 - INICIALIZADO COM SUCESSO   ║");
    Print("╚════════════════════════════════════════════════════╝");
    Print("EA Name: " + InpEAName);
    Print("Timeframe: " + IntegerToString(InpTimeframe));
    Print("Símbolos: " + InpSymbols);
    Print("Magic: " + IntegerToString(InpMagicNumber));
    Print("─────────────────────────────────────────────────── ");
    Print("Risco por Trade: " + DoubleToString(InpRiskPercent, 2) + "%");
    Print("Risco Máximo Dia: " + DoubleToString(InpMaxRiskDay, 2) + "%");
    Print("Stop Loss: " + IntegerToString(InpStopLossPoints) + " pts");
    Print("Take Profit: " + IntegerToString(InpTakeProfitPoints) + " pts");
    Print("─────────────────────────────────────────────────── ");
    Print("Trailing Stop: " + (InpUseTrailingStop ? "✅ ATIVADO" : "❌ DESATIVADO"));
    Print("Break Even: " + (InpUseBreakEven ? "✅ ATIVADO" : "❌ DESATIVADO"));
    Print("Venda Parcial: " + (InpUsePartialTake ? "✅ ATIVADO" : "❌ DESATIVADO"));
    Print("Auto Lot: " + (InpAutoLot ? "✅ ATIVADO" : "❌ DESATIVADO"));
    Print("╔════════════════════════════════════════════════════╗");
    Print("🚀 Pronto para GANHAR DINHEIRO!");
    Print("╚════════════════════════════════════════════════════╝\n");
}

string StringTrim(string str) {
    int len = StringLen(str);
    int start = 0;
    int end = len - 1;
    
    while(start < len && (str[start] == ' ' || str[start] == '\t')) start++;
    while(end >= 0 && (str[end] == ' ' || str[end] == '\t')) end--;
    
    if(start > end) return "";
    return StringSubstr(str, start, end - start + 1);
}

//+------------------------------------------------------------------+
//| End of Expert Advisor                                            |
//+------------------------------------------------------------------+