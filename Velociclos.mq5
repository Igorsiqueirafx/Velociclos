//+------------------------------------------------------------------+
//| EA_Fimathe_PCM_FixoAteOperacao_Otimizado.mq5
//| CA fixo até o término da operação | Ignora candle > 1.5x CA
//+------------------------------------------------------------------+
#property copyright "Automatização PCM - CA fixo Otimizado"
#property version   "1.12"
#property strict
#property description "CA fixo | Ignora candles > 1.5x CA | Reset + novo CA em movimentos extremos"

#include <trade\trade.mqh>
CTrade trade;

// Inputs
input int       VelasParaCA              = 4;
input double    Lote                     = 0.01;
// Input double    Lote                    = 0.01;
input double    RiscoPercent             = 2.0;        // K do saldo por operacao
input int       TamanhoMaximoCanal       = 1000;       // Fatia canais maiores que isso (pontos)
input int       Slippage                 = 3;
input int       TamanhoDaMaximaCanal     = 1000;       // Fátia canais maiores que isso (portos)
input int       SlipPage                 = 3;
input double    DistanciaSantinho        = 13          // Offset para SL (pontos)
input bool      DesenharObjetos          = true;
input bool      OtimizadoParaTeste       = true;
input color     Cor_CA                   = clBlue;
input color     Cor_C1                   = clBlue;
input color     Cor_C2                   = clBlue;
input color     Cor_Texto                = clBlue;

// Globals
datetime UltimaArraProcessada = 0;
bool     TemPosicaoAberta       = false;

double Preco_CA_Superior = 0;
double Preco_CA_Inferior = 0;
double Altura_CA         = 0;

double Preco_C1 = 0;
double Preco_C2 = 0;

bool CA_Criado   = false;
bool C1_Criado   = false;
bool C2_Criado   = false;
bool OrdemEnviada = false;

bool CA_Fatiado  = false;     // Indica se CA foi cortado em dois
double Preco_CA_Original = 0; // Armazena o CA original antes do corte

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime timeAtual = iTime(_Symbol, PERIOD_CURRENT, 0);

   if (UltimaArraProcessada == timeAtual)
      return;
   UltimaArraProcessada = timeAtual;

   // Criar CA se não existir
   if (!CA_Criado)
   {
      CriarCanalAbertura();
   }

   // Implementar lógica de fatiamento: se CA > TamanhoMaximoCanal, corta na metade
   if (CA_Criado && !CA_Fatiado && Altura_CA > TamanhoMaximoCanal * _Point)
   {
      FatiarCanalGrande();
   }

   // Criar C1 - verifica rompimento do CA
   if (CA_Criado && !C1_Criado && !OrdemEnviada)
   {
      double closeAnterior = iClose(_Symbol, PERIOD_CURRENT, 1);
      double topRompimento = Preco_CA_Superior;
      double bottomRompimento = Preco_CA_Inferior;

      if (closeAnterior > topRompimento || closeAnterior < bottomRompimento)
      {
         bool isBuy = (closeAnterior > topRompimento);
         double soma_amplitudes = 2 * Altura_CA;
         Preco_C1 = isBuy ? topRompimento + Altura_CA : bottomRompimento - Altura_CA;

         if (DesenharObjetos && !OtimizadoParaTeste)
         {
            CriarLinhaCanal("Linha_C1", Preco_C1, Cor_C1);
         }

         C1_Criado = true;
         Print("C1 criado em: ", DoubleToString(Preco_C1, _Digits));
      }
   }

   // Criar C2 + entra na operação
   if (C1_Criado && !C2_Criado && !OrdemEnviada)
   {
      double closeAnterior = iClose(_Symbol, PERIOD_CURRENT, 1);
      double top = MathMax(Preco_CA_Superior, Preco_C1);
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
//| Fatia Canal Grande                                              |
//+------------------------------------------------------------------+
void FatiarCanalGrande()
{
   // Se o CA for maior que TamanhoMaximoCanal pontos,
   // corta na metade: primeira metade = CA, segunda metade = C1
   if (Altura_CA <= TamanhoMaximoCanal * _Point)
      return; // Não precisa fatiar

   // Armazena o CA original
   Preco_CA_Original = Altura_CA;

   // Calcula a altura do novo CA (metade do original)
   double novaAltura = Altura_CA / 2.0;

   // Ajusta os limites do CA para a primeira metade (metade inferior)
   double pontoMeio = Preco_CA_Inferior + novaAltura;
   Preco_CA_Superior = pontoMeio;
   Altura_CA = novaAltura;

   // Define C1 como a segunda metade (imediatamente)
   Preco_C1 = pontoMeio + novaAltura; // Topo da segunda metade
   C1_Criado = true;

   CA_Fatiado = true;

   if (DesenharObjetos && !OtimizadoParaTeste)
   {
      CriarLinhaCanal("Linha_CA_Superior_Fatiado", Preco_CA_Superior, Cor_CA);
      CriarLinhaCanal("Linha_C1_Fatiado", Preco_C1, Cor_C1);
   }

   Print("Canal fatiado! CA original: ", DoubleToString(Preco_CA_Original, _Digits),
         " | Novo CA altura: ", DoubleToString(Altura_CA, _Digits),
         " | C1 criado em: ", DoubleToString(Preco_C1, _Digits));
}

//+------------------------------------------------------------------+
//| Cria o Canal de Abertura                                       |
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

   Print("CA FIXO criado",
         " -> Superior: ", DoubleToString(Preco_CA_Superior, _Digits),
         " | Inferior: ", DoubleToString(Preco_CA_Inferior, _Digits),
         " | Altura: ", DoubleToString(Altura_CA, _Digits));
}

//+------------------------------------------------------------------+
//| Reseta tudo                                                    |
//+------------------------------------------------------------------+
void ResetarTudo()
{
   CA_Criado = false;
   C1_Criado = false;
   C2_Criado = false;
   OrdemEnviada = false;
   CA_Fatiado = false;
   Preco_CA_Superior = 0;
   Preco_CA_Inferior = 0;
   Altura_CA = 0;
   Preco_CA_Original = 0;
   Preco_C1 = 0;
   Preco_C2 = 0;
}

//+------------------------------------------------------------------+
//| Executa Ordem                                                  |
//+------------------------------------------------------------------+
void ExecutarOrdem(bool isBuy)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double entrada = isBuy ? ask : bid;
   double sl = isBuy ? (Preco_C2 - (DistanciaSantinho * _Point)) : (Preco_C2 + (DistanciaSantinho * _Point));
   double tp = isBuy ? (Preco_C2 * 2 - entrada) : (Preco_C2 * 2 - entrada);

   if (trade.Buy(Lote, _Symbol, entrada, sl, tp, "PCM - Operação"))
   {
      TemPosicaoAberta = true;
      Print("Ordem executada com sucesso!");
   }
   else
   {
      Print("Erro ao executar ordem: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Cria Linha do Canal                                             |
//+------------------------------------------------------------------+
void CriarLinhaCanal(string nome, double preco, color cor)
{
   if (ObjectFind(0, nome) >= 0)
      ObjectDelete(0, nome);

   ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Exibir Texto                                                   |
//+------------------------------------------------------------------+
void ExibirTexto(string nome, string texto, double preco1, double preco2)
{
   if (ObjectFind(0, nome) >= 0)
      ObjectDelete(0, nome);

   ObjectCreate(0, nome, OBJ_TEXT, 0, TimeCurrent(), (preco1 + preco2) / 2.0);
   ObjectSetString(0, nome, OBJPROP_TEXT, texto);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, Cor_Texto);
   ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, 12);
}
//+------------------------------------------------------------------+
