//+------------------------------------------------------------------+
//| EA_Fimathe_PCM_FixoAteOperacao_Otimizado.mq5                     |
//| CA fixo até o término da operação | Ignora candle > 1.5× CA      |
//+------------------------------------------------------------------+
#property copyright "Automatização PCM - CA fixo Otimizado"
#property version   "1.10"
#property strict
#property description "CA fixo | Ignora candles > 1.5× CA | Reset + novo CA em movimentos extremos"

#include <Trade\Trade.mqh>
CTrade trade;

// Inputs
input int      VelasParaCA         = 4;
// input double   Lote                = 0.01;
input double   RiscoPercent           = 2.0;          // % do saldo por operacao
input int      Slippage            = 3;
input double   DistanciaSantinho   = 33            // Offset para SL (pontos)
input double   OffsetTP_Pontos     =  33;           // Offset para TP (positivo = além C2)
input double   IgnorarCandleMaiorQue = 1.5;          // Ignora candle se amplitude ≥ X × Altura_CA
input bool     DesenharObjetos     = true;
input bool     OtimizadoParaTeste  = true;
input color    Cor_CA              = clrBlue;
input color    Cor_C1              = clrBlue;
input color    Cor_C2              = clrBlue;
input color    Cor_Texto           = clrBlue;

// Globais
datetime UltimaBarraProcessada = 0;
bool     TemPosicaoAberta      = false;

double Preco_CA_Superior = 0;
double Preco_CA_Inferior = 0;
double Altura_CA         = 0;

double Preco_C1 = 0;
double Preco_C2 = 0;

bool CA_Criado   = false;
bool C1_Criado   = false;
bool C2_Criado   = false;
bool OrdemEnviada = false;

//+------------------------------------------------------------------+
//| Calcula lote baseado em % de risco                               |
//+------------------------------------------------------------------+
double CalculaLotePorRisco(double precoEntrada, double slPrice)
{
   double saldo    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riscoVal = saldo * (RiscoPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if (tickValue <= 0.0 || tickSize <= 0.0)
   {
      Print("Erro: tickValue ou tickSize invalidos para simbolo ", _Symbol);
      return(0.0);
   }

   double distanciaPreco = MathAbs(precoEntrada - slPrice);
   double distanciaTicks = distanciaPreco / tickSize;

   if (distanciaTicks <= 0.0)
   {
      Print("Erro: distanciaTicks <= 0, precoEntrada=", precoEntrada, " sl=", slPrice);
      return(0.0);
   }

   double perdaPorLote = distanciaTicks * tickValue;
   if (perdaPorLote <= 0.0)
   {
      Print("Erro: perdaPorLote <= 0");
      return(0.0);
   }

   double loteBruto = riscoVal / perdaPorLote;

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if (lotStep <= 0.0)
      lotStep = 0.01;

   double lote = MathFloor(loteBruto / lotStep) * lotStep;

   if (lote < minLot) lote = minLot;
   if (lote > maxLot) lote = maxLot;

   Print("RiscoPercent=", DoubleToString(RiscoPercent, 2),
         "% | Saldo=", DoubleToString(saldo, 2),
         " | RiscoVal=", DoubleToString(riscoVal, 2),
         " | DistTicks=", DoubleToString(distanciaTicks, 2),
         " | LoteBruto=", DoubleToString(loteBruto, 3),
         " | LoteFinal=", DoubleToString(lote, 3));

   return(lote);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetDeviationInPoints(Slippage);
   LimparObjetosAntigos();
   Print("EA inicializado | IgnorarCandleMaiorQue=", IgnorarCandleMaiorQue);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LimparObjetosAntigos();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   bool agoraTemPosicao = (PositionsTotal() > 0);
   
   if (agoraTemPosicao != TemPosicaoAberta)
   {
      TemPosicaoAberta = agoraTemPosicao;
      
      if (!TemPosicaoAberta)
      {
         Print(TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES), 
               " - Posição fechada → resetando CA e ciclos");
         ResetarTudo();
      }
   }

   datetime tempoAtual = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (tempoAtual == UltimaBarraProcessada) return;
   UltimaBarraProcessada = tempoAtual;

   if (TemPosicaoAberta) return;

   if (!CA_Criado)
   {
      CriarCanalAbertura();
   }

   if (!CA_Criado) return;

   double openAnterior  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double closeAnterior = iClose(_Symbol, PERIOD_CURRENT, 1);
   double highAnterior  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double lowAnterior   = iLow(_Symbol, PERIOD_CURRENT, 1);

   double amplitudeCandle = highAnterior - lowAnterior;
   double limiarGrande    = IgnorarCandleMaiorQue * Altura_CA;

   // Ignora candle se for maior que o limiar (ex: > 1.5 × CA)
   if (amplitudeCandle >= limiarGrande)
   {
      Print(TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS),
            " - Candle ignorado (grande demais): amplitude=", DoubleToString(amplitudeCandle,_Digits),
            " >= limiar=", DoubleToString(limiarGrande,_Digits));
      return;  // Pula essa barra, continua na próxima
   }

   // Reset + novo CA se candle abre no CA e fecha muito longe (exemplo da foto)
   bool abreNoCA = (openAnterior >= Preco_CA_Inferior && openAnterior <= Preco_CA_Superior);
   bool fechaMuitoLonge = (C2_Criado && 
                           ((closeAnterior > Preco_C2 + Altura_CA) || (closeAnterior < Preco_C2 - Altura_CA)));

   if (abreNoCA && fechaMuitoLonge)
   {
      Print(TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS),
            " - Candle abre no CA e fecha fora do C2 extremo → RESET + novo CA");
      ResetarTudo();
      CriarCanalAbertura();  // Força novo CA imediatamente
      return;
   }

   // Cria C1 se rompimento normal
   if (!C1_Criado)
   {
      bool fechaFora = (closeAnterior > Preco_CA_Superior || closeAnterior < Preco_CA_Inferior);

      if (fechaFora)
      {
         bool alta = (closeAnterior > Preco_CA_Superior);
         Preco_C1 = alta ? Preco_CA_Superior + Altura_CA : Preco_CA_Inferior - Altura_CA;

         if (DesenharObjetos && !OtimizadoParaTeste)
         {
            CriarLinhaCanal("Linha_C1", Preco_C1, Cor_C1);
            ExibirTexto("Texto_C1", "C1", alta ? Preco_CA_Superior : Preco_C1, alta ? Preco_C1 : Preco_CA_Inferior);
         }

         C1_Criado = true;
         Print("C1 criado em: ", DoubleToString(Preco_C1, _Digits));
      }
   }

   // Cria C2 + entra na operação
   if (C1_Criado && !C2_Criado && !OrdemEnviada)
   {
      double top    = MathMax(Preco_CA_Superior, Preco_C1);
      double bottom = MathMin(Preco_CA_Inferior, Preco_C1);

      if (closeAnterior > top || closeAnterior < bottom)
      {
         bool isBuy = (closeAnterior > top);
         double soma_amplitudes = 2 * Altura_CA;
         Preco_C2 = isBuy ? top + soma_amplitudes : bottom - soma_amplitudes;

         if (DesenharObjetos && !OtimizadoParaTeste)
         {
            CriarLinhaCanal("Linha_C2", Preco_C2, Cor_C2);
            ExibirTexto("Texto_C2", "C2", isBuy ? top : bottom, isBuy ? Preco_C2 : bottom);
            
            double offset = DistanciaSantinho * _Point;
            ExibirTexto("Texto_Dedinho", "$", Preco_C2, Preco_C2 + (isBuy ? -offset : +offset));
         }

         ExecutarOrdem(isBuy);

         C2_Criado = true;
         OrdemEnviada = true;
         Print("C2 criado + ordem enviada: ", isBuy ? "COMPRA" : "VENDA");
      }
   }
}

//+------------------------------------------------------------------+
//| Cria o Canal de Abertura                                         |
//+------------------------------------------------------------------+
void CriarCanalAbertura()
{
   MqlRates rates[];
   ArrayResize(rates, VelasParaCA);
   ArraySetAsSeries(rates, true);

   if (CopyRates(_Symbol, PERIOD_CURRENT, 1, VelasParaCA, rates) != VelasParaCA)
   {
      Print("Erro ao copiar rates para CA");
      return;
   }

   double maximo = rates[0].high;
   double minimo = rates[0].low;

   for (int i = 1; i < VelasParaCA; i++)
   {
      maximo = MathMax(maximo, rates[i].high);
      minimo = MathMin(minimo, rates[i].low);
   }

   if (maximo <= minimo) return;

   Preco_CA_Superior = maximo;
   Preco_CA_Inferior = minimo;
   Altura_CA = maximo - minimo;

   CA_Criado = true;

   if (DesenharObjetos && !OtimizadoParaTeste)
   {
      CriarLinhaCanal("Linha_CA_Superior", Preco_CA_Superior, Cor_CA);
      CriarLinhaCanal("Linha_CA_Inferior", Preco_CA_Inferior, Cor_CA);
      ExibirTexto("Texto_CA", "CA", Preco_CA_Superior, Preco_CA_Inferior);
   }

   Print("CA FIXO criado → Superior: ", DoubleToString(Preco_CA_Superior,_Digits),
         " | Inferior: ", DoubleToString(Preco_CA_Inferior,_Digits),
         " | Altura: ", DoubleToString(Altura_CA,_Digits));
}

//+------------------------------------------------------------------+
//| Reseta tudo                                                      |
//+------------------------------------------------------------------+
void ResetarTudo()
{
   CA_Criado    = false;
   C1_Criado    = false;
   C2_Criado    = false;
   OrdemEnviada = false;

   Preco_CA_Superior = 0;
   Preco_CA_Inferior = 0;
   Altura_CA         = 0;
   Preco_C1          = 0;
   Preco_C2          = 0;

   LimparObjetosAntigos();
}

//+------------------------------------------------------------------+
//| Cria linha horizontal                                            |
//+------------------------------------------------------------------+
void CriarLinhaCanal(string nome, double preco, color cor)
{
   if (ObjectFind(0, nome) >= 0) ObjectDelete(0, nome);
   
   ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
}

//+------------------------------------------------------------------+
//| Exibe texto no centro                                            |
//+------------------------------------------------------------------+
void ExibirTexto(string nome, string texto, double p1, double p2)
{
   if (ObjectFind(0, nome) >= 0)
      ObjectDelete(0, nome);

   double centro = (p1 + p2) / 2.0;
   datetime tempo = iTime(_Symbol, PERIOD_CURRENT, 0);

   ObjectCreate(0, nome, OBJ_TEXT, 0, tempo, centro);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, Cor_Texto);
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, nome, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Executa ordem com TP ajustável                                   |
//+------------------------------------------------------------------+
void ExecutarOrdem(bool isBuy)
{
   double offset_sl = DistanciaSantinho * _Point;
   double offset_tp = OffsetTP_Pontos * _Point;

   double precoEntrada = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl, tp;

   if (isBuy)
   {
      sl = MathMin(Preco_CA_Inferior, Preco_C1) - offset_sl;
      tp = Preco_C2 + offset_tp;
   }
   else
   {
      sl = MathMax(Preco_CA_Superior, Preco_C1) + offset_sl;
      tp = Preco_C2 - offset_tp;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // calculo de lote por risco
   double lote = CalculaLotePorRisco(precoEntrada, sl);
   if (lote <= 0.0)
   {
      Print("Falha no calculo do lote. Lote=", DoubleToString(lote, 2));
      return;
   }

   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lote;
   request.type      = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price     = precoEntrada;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = Slippage;
   request.magic     = 123456;
   request.comment   = "PCM Rompimento";

   if (!OrderSend(request, result))
   {
      Print("Erro ao enviar ordem: ", result.retcode, " - ", GetLastError());
   }
   else
   {
      Print("Ordem executada: ", isBuy ? "COMPRA" : "VENDA", 
            " | TP ajustado: ", DoubleToString(tp, _Digits), 
            " | Ticket: ", result.order);
   }
}

//+------------------------------------------------------------------+
//| Limpa objetos do gráfico                                         |
//+------------------------------------------------------------------+
void LimparObjetosAntigos()
{
   ObjectsDeleteAll(0, "Linha_");
   ObjectsDeleteAll(0, "Texto_");
}
