#property copyright "Copyright 2025, Hung Thinh AI"
#property version   "1.1"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Define Macro Codes                                               |
//+------------------------------------------------------------------+
#define MB_YESNO		0x00000004
#define IDYES			6

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
bool   ECN=true; //set true if using ECN broker. If true then EA will open orders with SL=0 and TP=0 and will modify these parameters after order(including pending) is executed
input string _0_="Hung Thinh XAU AI v1.1";
input string _1_="===== Hung Thinh XAU AI settings =====";
input bool   New_Cycle=true;
input bool   Auto_Detect_5_Digit_Brokers=false;
input int    MAGIC=7774;
input double Slippage=6;
input double Max_Trades=30;
input double Max_Lot=2;

input string _2_ = "================ TP settings ================";
input double TP_Input=1500;
input double TP1_Input=1500;
input bool   VTP=true;
input double Tral_Start_Input=0;
input double Tral_Size_Input=0;

input string _3_            =  "================ He thong giam thieu rui ro ================";
input bool   RRS            =  false;
input int    RRS_nOrder         =  3;
input double RRS_TP_Input          =  300;
input double RRS_Tral_Start_Input  =  70;
input double RRS_Tral_Size_Input   =  40;
input double RRS_Profit_Percent  =  40;

input string _4_            =  "================ Buy settings ================";
input double Min_Lot_Buy=0.02;
input double Lot_Exp_Buy=1.2;
input double Step_Buy=350;
input double Step_Buy_2=800;
input double Step_Buy_3=1500;
input double Step_Coef_Buy=1.05;
input int    Step_Coef_Start_Order_Buy=15;
input string Step_Mass_Buy="60,60,60,60,60,60,80,80,90,120,120,120,150,150,150,200";

input string _5_            =  "================ Sell settings ================";
input double Min_Lot_Sell=0.02;
input double Lot_Exp_Sell=1.2;
input double Step_Sell=350;
input double Step_Sell_2=800;
input double Step_Sell_3=1500;
input double Step_Coef_Sell=1.05;
input int    Step_Coef_Start_Order_Sell=15;
input string Step_Mass_Sell="60,60,60,60,60,60,80,80,90,120,120,120,150,150,150,200";

input string _6_            =  "================ Color settings ================";
input color  Buy_BE_Color=RoyalBlue;
input color  Sell_BE_Color=Tomato;
input color  Buy_TP_Color=DarkBlue;
input color  Sell_TP_Color=Red;
input color  Buy_Trall_Color=Yellow;
input color  Sell_Trall_Color=Magenta;
input color  Buy_LOT_Trall_Color=Yellow;
input color  Sell_LOT_Trall_Color=Magenta;
input color  RRS_Color_Sell   =  Purple;
input color  RRS_Color_Buy    =  OrangeRed;

// Working variables (can be modified)
double TP, TP1, Tral_Start, Tral_Size, RRS_TP, RRS_Tral_Start, RRS_Tral_Size;

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
double SL=0;
int x=1;
double Orders[2][100][10]; // first dimension: 0 - buys, 1 - sells
                           // second dimension: orders according to magic number
                           // third dimension: 0 - OrderTicket, 1 - OrderType, 2 - OrderLots, 3 - OrderOpenPrice,
                           // 4 - OrderStopLoss, 5 - OrderTakeProfit, 6 - point cost according to lot
int TotalOrders[2];
double lastPriceBuy, lastPriceSell;
double TrallBuys=-1, TrallSells=-1, LotTrallBuys=-1, LotTrallSells=-1;
double BuysBE, SellsBE, BuysTP, SellsTP, LOTBuysBE, LOTSellsBE, LOTBuysTP, LOTSellsTP;

CTrade trade;
CPositionInfo posInfo;
COrderInfo ordInfo;

//+------------------------------------------------------------------+
//| Creates Label object on the chart                                |
//+------------------------------------------------------------------+
bool ObjectCreateEx(string objname, int YOffset, int XOffset=0, int objType=OBJ_LABEL, int corner=0, bool background=false)
{
   bool needNUL=false;
   if(ObjectFind(0, objname)==-1)
   {
      needNUL=true;
      ObjectCreate(0, objname, objType, 0, 0.0, 0.0);
   }

   ObjectSetInteger(0, objname, OBJPROP_YDISTANCE, YOffset);
   ObjectSetInteger(0, objname, OBJPROP_XDISTANCE, XOffset);
   ObjectSetInteger(0, objname, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, objname, OBJPROP_BACK, background);
   if(needNUL) ObjectSetString(0, objname, OBJPROP_TEXT, "");
   return(true);
}

int BuyObj[2], SellObj[2];

//+------------------------------------------------------------------+
//| EA initialization function                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   // Copy input values to working variables
   TP=TP_Input;
   TP1=TP1_Input;
   Tral_Start=Tral_Start_Input;
   Tral_Size=Tral_Size_Input;
   RRS_TP=RRS_TP_Input;
   RRS_Tral_Start=RRS_Tral_Start_Input;
   RRS_Tral_Size=RRS_Tral_Size_Input;

   if(RRS_Tral_Size>RRS_Tral_Start)
   {
      RRS_Tral_Size=RRS_Tral_Start;
      Alert("RRS_Tral_Size>RRS_Tral_Start. Please check EA settings");
   }
   if(Tral_Size>Tral_Start)
   {
      Tral_Size=Tral_Start;
      Alert("Tral_Size>Tral_Start. Please check EA settings");
   }
   if(Auto_Detect_5_Digit_Brokers && (Digits()==3 || Digits()==5)) x=10;

   TP=TP*Point()*x;
   TP1=TP1*Point()*x;
   SL=SL*Point()*x;
   RRS_TP=RRS_TP*Point()*x;
   RRS_Tral_Size=RRS_Tral_Size*Point()*x;
   RRS_Tral_Start=RRS_Tral_Start*Point()*x;
   Tral_Size=Tral_Size*Point()*x;
   Tral_Start=Tral_Start*Point()*x;

   BuyObj[0]=350;
   BuyObj[1]=22;
   SellObj[0]=350;
   SellObj[1]=322;

   ObjectCreateEx("_Benefit_error", 20, 20);
   ObjectCreateEx("_Benefit_OpenBuy", BuyObj[1], BuyObj[0], OBJ_LABEL, 0, false);
   ObjectCreateEx("_Benefit_OpenSell", SellObj[1], SellObj[0], OBJ_LABEL, 0, false);

   ObjectSetString(0, "_Benefit_OpenBuy", OBJPROP_TEXT, "5");
   ObjectSetString(0, "_Benefit_OpenSell", OBJPROP_TEXT, "6");

   // Create horizontal lines for TP and BE levels
   ObjectCreate(0, "_Benefit_BuyBE", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_BuyBE", OBJPROP_COLOR, Buy_BE_Color);
   ObjectSetInteger(0, "_Benefit_BuyBE", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_BuyBE", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_SellBE", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_SellBE", OBJPROP_COLOR, Sell_BE_Color);
   ObjectSetInteger(0, "_Benefit_SellBE", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_SellBE", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_LotTPBuy", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_LotTPBuy", OBJPROP_COLOR, RRS_Color_Buy);
   ObjectSetInteger(0, "_Benefit_LotTPBuy", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "_Benefit_LotTPBuy", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_LotTPSell", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_LotTPSell", OBJPROP_COLOR, RRS_Color_Sell);
   ObjectSetInteger(0, "_Benefit_LotTPSell", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "_Benefit_LotTPSell", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_BuyTP", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_BuyTP", OBJPROP_COLOR, Buy_TP_Color);
   ObjectSetInteger(0, "_Benefit_BuyTP", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "_Benefit_BuyTP", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_SellTP", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_SellTP", OBJPROP_COLOR, Sell_TP_Color);
   ObjectSetInteger(0, "_Benefit_SellTP", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "_Benefit_SellTP", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_SellTrall", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_SellTrall", OBJPROP_COLOR, Sell_Trall_Color);
   ObjectSetInteger(0, "_Benefit_SellTrall", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_SellTrall", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_BuyTrall", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_BuyTrall", OBJPROP_COLOR, Buy_Trall_Color);
   ObjectSetInteger(0, "_Benefit_BuyTrall", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_BuyTrall", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_SellLOTTrall", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_SellLOTTrall", OBJPROP_COLOR, Sell_LOT_Trall_Color);
   ObjectSetInteger(0, "_Benefit_SellLOTTrall", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_SellLOTTrall", OBJPROP_BACK, 1);

   ObjectCreate(0, "_Benefit_BuyLOTTrall", OBJ_HLINE, 0, 0, 0.0);
   ObjectSetInteger(0, "_Benefit_BuyLOTTrall", OBJPROP_COLOR, Buy_LOT_Trall_Color);
   ObjectSetInteger(0, "_Benefit_BuyLOTTrall", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, "_Benefit_BuyLOTTrall", OBJPROP_BACK, 1);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EA start function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //=======================================Some variables initialization
   double sl,tp,op,lot;
   int i, j;
   ObjectSetString(0, "_Benefit_error", OBJPROP_TEXT, "");

   double Level=MathMax(SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(Symbol(),SYMBOL_TRADE_FREEZE_LEVEL))*Point()*x;

   //==========================================Filling array Orders of opened trades information
   ArrayInitialize(Orders,-1);
   ArrayInitialize(TotalOrders,0);
   ulong NeedCloseAll=-1;
   lastPriceBuy=0; lastPriceSell=0;
   double highestBuy=-1, lowestBuy=-1, highestSell=-1, lowestSell=-1;
   double profitBuys=0, profitSells=0;
   int buys=0, sells=0;
   double lotsBuys=0, lotsSells=0;
   datetime firstBuyTime=0, firstSellTime=0;

   for(int p=PositionsTotal()-1;p>=0;p--)
   {
      if(!posInfo.SelectByIndex(p)) continue;
      if(posInfo.Symbol()!=Symbol()) continue;

      if(posInfo.Magic()==MAGIC+1)
      {
         NeedCloseAll=posInfo.Ticket();
         continue;
      }

      if(posInfo.Magic()!=MAGIC) continue;

      int index=0;
      if(posInfo.PositionType()==POSITION_TYPE_SELL)
         index=1;

      if(NO(lastPriceBuy)==0 && posInfo.PositionType()==POSITION_TYPE_BUY) lastPriceBuy=posInfo.PriceOpen();
      if(NO(lastPriceSell)==0 && posInfo.PositionType()==POSITION_TYPE_SELL) lastPriceSell=posInfo.PriceOpen();

      if(posInfo.PositionType()==POSITION_TYPE_BUY)
      {
         if(NO(highestBuy)<0 || NO(posInfo.PriceOpen())>NO(highestBuy)) highestBuy=posInfo.PriceOpen();
         if(NO(lowestBuy)<0 || NO(posInfo.PriceOpen())<NO(lowestBuy)) lowestBuy=posInfo.PriceOpen();
         profitBuys+=posInfo.Profit();
         lotsBuys+=posInfo.Volume();
         buys++;
         if(firstBuyTime==0 || posInfo.Time()<firstBuyTime) firstBuyTime=posInfo.Time();
      }
      if(posInfo.PositionType()==POSITION_TYPE_SELL)
      {
         if(NO(highestSell)<0 || NO(posInfo.PriceOpen())>NO(highestSell)) highestSell=posInfo.PriceOpen();
         if(NO(lowestSell)<0 || NO(posInfo.PriceOpen())<NO(lowestSell)) lowestSell=posInfo.PriceOpen();
         profitSells+=posInfo.Profit();
         lotsSells+=posInfo.Volume();
         sells++;
         if(firstSellTime==0 || posInfo.Time()<firstSellTime) firstSellTime=posInfo.Time();
      }

      Orders[index][TotalOrders[index]][0]=(double)posInfo.Ticket();
      Orders[index][TotalOrders[index]][1]=posInfo.PositionType();
      Orders[index][TotalOrders[index]][2]=posInfo.Volume();
      Orders[index][TotalOrders[index]][3]=posInfo.PriceOpen();
      Orders[index][TotalOrders[index]][4]=posInfo.StopLoss();
      Orders[index][TotalOrders[index]][5]=posInfo.TakeProfit();
      Orders[index][TotalOrders[index]][6]=PointCost(posInfo.Volume());
      TotalOrders[index]++;
   }

   if(TotalOrders[0]<1)
   {
      LotTrallBuys=-1;
      TrallBuys=-1;
   }

   if(TotalOrders[1]<1)
   {
      LotTrallSells=-1;
      TrallSells=-1;
   }

   //==========================================Closing current cycle and deleting close/delete signal order
   bool NeedReturn=false;
   if(NeedCloseAll>=0)
   {
      // Find and close all positions based on signal
      int index=-1;
      if(posInfo.SelectByTicket(NeedCloseAll))
      {
         if(posInfo.PositionType()==POSITION_TYPE_BUY && TotalOrders[0]>0) index=0;
         if(posInfo.PositionType()==POSITION_TYPE_SELL && TotalOrders[1]>0) index=1;
      }

      if(index==0)
      {
         for(i=0;i<TotalOrders[0];i++)
         {
            if(Orders[0][i][0]<0) continue;
            if(!posInfo.SelectByTicket(DtI(Orders[0][i][0]))) continue;
            if(posInfo.Symbol()!=Symbol()) continue;
            trade.PositionClose(posInfo.Ticket());
         }
         NeedReturn=true;
      }

      if(index==1)
      {
         for(i=0;i<TotalOrders[1];i++)
         {
            if(Orders[1][i][0]<0) continue;
            if(!posInfo.SelectByTicket(DtI(Orders[1][i][0]))) continue;
            if(posInfo.Symbol()!=Symbol()) continue;
            trade.PositionClose(posInfo.Ticket());
         }
         NeedReturn=true;
      }

      if(NeedReturn) return;
   }

   //==========================================Check for close all && count history profit
   int closeBuys=0, closeSells=0;
   double historyProfitBuys=0, historyProfitSells=0;
   bool countBuys=true, countSells=true;
   double dayProfit=0, weekProfit=0;

   HistorySelect(0, TimeCurrent());
   for(int tr=HistoryDealsTotal()-1;tr>=0;tr--)
   {
      ulong ticket=HistoryDealGetTicket(tr);
      if(ticket<0) break;

      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC)!=MAGIC && (long)HistoryDealGetInteger(ticket, DEAL_MAGIC)!=MAGIC+1)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL)!=Symbol())
         continue;

      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC)==MAGIC+1)
      {
         if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_BUY) countBuys=false;
         if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_SELL) countSells=false;
      }

      datetime dealTime=(datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      double dealProfit=HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(dealTime>=iTime(NULL, PERIOD_D1, 0))
         dayProfit+=dealProfit;

      if(dealTime>=iTime(NULL, PERIOD_W1, 0))
         weekProfit+=dealProfit;

      if(!countSells && !countBuys && dealTime<iTime(NULL, PERIOD_W1, 0)) break;

      if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_BUY && countBuys)
         closeBuys++;

      if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_SELL && countSells)
         closeSells++;

      if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_BUY && dealTime>firstBuyTime && firstBuyTime>0)
         historyProfitBuys=historyProfitBuys+dealProfit;

      if((long)HistoryDealGetInteger(ticket, DEAL_TYPE)==DEAL_SELL && dealTime>firstSellTime && firstSellTime>0)
         historyProfitSells=historyProfitSells+dealProfit;
   }

   //==========================================Signal determination
   bool Buy=false, Sell=false;
   j=TotalOrders[0]-Step_Coef_Start_Order_Buy+2;
   if(j<0) j=0;
   double buystep=Step_Buy*MathPow(Step_Coef_Buy, j);
   if(NO(Step_Coef_Buy)==0) buystep=ParseStepMass(TotalOrders[0], 0);

   double close2=iClose(Symbol(),PERIOD_CURRENT,2);
   double open2=iOpen(Symbol(),PERIOD_CURRENT,2);
   double close1=iClose(Symbol(),PERIOD_CURRENT,1);
   double open1=iOpen(Symbol(),PERIOD_CURRENT,1);
   datetime time0=iTime(Symbol(),PERIOD_CURRENT,0);

   Buy=(((TotalOrders[0]==0 && NO(close2)>NO(open2) && NO(close1)>NO(open1)) || TotalOrders[0]>0)
        && (!ThereIsOrderOnThisBar(time0, POSITION_TYPE_BUY) && (lastPriceBuy-SymbolInfoDouble(Symbol(),SYMBOL_ASK)>=buystep*Point()*x || NO(lastPriceBuy)==0)));

   j=TotalOrders[1]-Step_Coef_Start_Order_Sell+2;
   if(j<0) j=0;
   double sellstep=Step_Sell*MathPow(Step_Coef_Sell, j);
   if(NO(Step_Coef_Sell)==0) sellstep=ParseStepMass(TotalOrders[1], 1);

   Sell=(((TotalOrders[1]==0 && NO(close2)<NO(open2) && NO(close1)<NO(open1)) || TotalOrders[1]>0)
        && (!ThereIsOrderOnThisBar(time0, POSITION_TYPE_SELL) && (SymbolInfoDouble(Symbol(),SYMBOL_BID)-lastPriceSell>=sellstep*Point()*x || NO(lastPriceSell)==0)));

   //==========================================Calculation and drawing of BE/TP
   SellsTP=0; BuysTP=0;
   double TheSumm=0, TheSumm2=0, dTemp=0;
   BuysBE=0; SellsBE=0; LOTSellsBE=-1; LOTBuysBE=-1;
   ObjectSetDouble(0, "_Benefit_BuyBE", OBJPROP_PRICE, 0);

   if(TotalOrders[0]>0)
   {
      for(int cikl=0;cikl<=(highestBuy-lowestBuy)/Point();cikl++)
      {
         BuysBE=lowestBuy+cikl*Point();
         TheSumm=0;
         TheSumm2=0;
         for(i=0;i<TotalOrders[0];i++)
         {
            dTemp=(BuysBE-Orders[0][i][3])/Point()*Orders[0][i][6];
            TheSumm=TheSumm+dTemp;
            if(i<2) TheSumm2=TheSumm2+dTemp;
         }

         if(NO(TheSumm2)>=0.0 && LOTBuysBE<0) LOTBuysBE=BuysBE;

         if(NO(TheSumm)>=0.0)
         {
            ObjectSetDouble(0, "_Benefit_BuyBE", OBJPROP_PRICE, BuysBE);
            if(NO(TP1)!=0.0) BuysTP=BuysBE+TP1; else BuysTP=0;
            if(TotalOrders[0]>1 && NO(TP)!=0.0) BuysTP=BuysBE+TP;
            break;
         }
      }
   }

   ObjectSetDouble(0, "_Benefit_SellBE", OBJPROP_PRICE, 0);
   if(TotalOrders[1]>0)
   {
      for(int cikl=(int)((highestSell-lowestSell)/Point());cikl>=0;cikl--)
      {
         SellsBE=lowestSell+cikl*Point();
         TheSumm=0;
         TheSumm2=0;
         for(i=0;i<TotalOrders[1];i++)
         {
            dTemp=(Orders[1][i][3]-SellsBE)/Point()*Orders[1][i][6];
            TheSumm=TheSumm+dTemp;
            if(i<2) TheSumm2=TheSumm2+dTemp;
         }

         if(NO(TheSumm2)>=0.0 && LOTSellsBE<0) LOTSellsBE=SellsBE;

         if(NO(TheSumm)>=0.0)
         {
            ObjectSetDouble(0, "_Benefit_SellBE", OBJPROP_PRICE, SellsBE);
            if(NO(TP1)!=0.0) SellsTP=SellsBE-TP1; else SellsTP=0;
            if(TotalOrders[1]>1 && NO(TP)!=0.0) SellsTP=SellsBE-TP;
            break;
         }
      }
   }

   LOTBuysTP=LOTBuysBE+RRS_TP;
   LOTSellsTP=LOTSellsBE-RRS_TP;

   ObjectSetDouble(0, "_Benefit_LotTPBuy", OBJPROP_PRICE, 0);
   ObjectSetDouble(0, "_Benefit_LotTPSell", OBJPROP_PRICE, 0);
   ObjectSetDouble(0, "_Benefit_BuyTP", OBJPROP_PRICE, 0);
   ObjectSetDouble(0, "_Benefit_SellTP", OBJPROP_PRICE, 0);

   if(NO(BuysTP)>0) ObjectSetDouble(0, "_Benefit_BuyTP", OBJPROP_PRICE, BuysTP);
   if(NO(SellsTP)>0) ObjectSetDouble(0, "_Benefit_SellTP", OBJPROP_PRICE, SellsTP);

   if(LOTBuysBE>0 && TotalOrders[0]>=RRS_nOrder && RRS) ObjectSetDouble(0, "_Benefit_LotTPBuy", OBJPROP_PRICE, LOTBuysTP);
   if(LOTSellsBE>0 && TotalOrders[1]>=RRS_nOrder && RRS) ObjectSetDouble(0, "_Benefit_LotTPSell", OBJPROP_PRICE, LOTSellsTP);

   //==========================================Info panel
   double freeMgn=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq=SymbolInfoDouble(Symbol(), SYMBOL_MARGIN_REQUIREMENT);
   double maxlot=(marginReq>0)?freeMgn/marginReq:0;

   if(!IsTesting() || (IsTesting() && IsVisualMode()))
   {
      int Yt[3]={50, 350, 200}, Xt[3]={110, 110, 110};
      color textColor=White;

      ObjectCreateEx("_Benefit_t1_body", Yt[0]-30, Xt[0]-5, OBJ_LABEL, 0, true);
      ObjectSetString(0, "_Benefit_t1_body", OBJPROP_TEXT, "ggg");

      ObjectCreateEx("_Benefit_t1_Header", Yt[0]-25, Xt[0]+110, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_Header", OBJPROP_TEXT, "BUY-SIDE");

      ObjectCreateEx("_Benefit_t1_1_1", Yt[0], Xt[0], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_1_1", OBJPROP_TEXT, "Orders: "+IntegerToString(buys));

      ObjectCreateEx("_Benefit_t1_1_2", Yt[0]+15, Xt[0], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_1_2", OBJPROP_TEXT, "Volume: "+DoubleToString(lotsBuys, 2));

      ObjectCreateEx("_Benefit_t1_1_3", Yt[0]+30, Xt[0], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_1_3", OBJPROP_TEXT, "TP Level: "+DoubleToString(BuysTP, (int)Digits()));

      ObjectCreateEx("_Benefit_t1_1_4", Yt[0]+45, Xt[0], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_1_4", OBJPROP_TEXT, "LTP Level: "+DoubleToString(LOTBuysTP, (int)Digits()));

      ObjectCreateEx("_Benefit_t1_2_1", Yt[0], Xt[0]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_2_1", OBJPROP_TEXT, "Profit: "+DoubleToString(profitBuys, 2));

      ObjectCreateEx("_Benefit_t1_2_3", Yt[0]+15, Xt[0]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t1_2_3", OBJPROP_TEXT, "BE Level: "+DoubleToString(BuysBE, (int)Digits()));

      ObjectCreateEx("_Benefit_t1_2_4", Yt[0]+30, Xt[0]+160, OBJ_LABEL, 0);
      double lotProfit = (historyProfitBuys/(AccountInfoDouble(ACCOUNT_BALANCE)-historyProfitBuys)*100);
      ObjectSetString(0, "_Benefit_t1_2_4", OBJPROP_TEXT, "Lot Profit: "+DoubleToString(lotProfit, 2)+"%");

      double w1;
      double loclot=0;
      int next=Xt[0];
      int y=Yt[0];
      color col2=textColor;

      for(i=0; i<16; i++)
      {
         j=i-Step_Coef_Start_Order_Buy+2;
         if(j<0) j=0;
         w1=Step_Buy*MathPow(Step_Coef_Buy, j);
         if(NO(Step_Coef_Buy)==0) w1=ParseStepMass(i+1, 0);

         ObjectCreateEx("_Benefit_t1_3_"+IntegerToString(i), y+75, next, OBJ_LABEL, 0);
         col2=textColor;
         if(TotalOrders[0]>=i+1) col2=RoyalBlue;
         dTemp=GetLot(0, i+1);
         loclot+=dTemp;

         ObjectSetString(0, "_Benefit_t1_3_"+IntegerToString(i), OBJPROP_TEXT, "|"+DoubleToString(w1, 0));

         ObjectCreateEx("_Benefit_t1_3L_"+IntegerToString(i), y+90, next, OBJ_LABEL, 0);
         ObjectSetString(0, "_Benefit_t1_3L_"+IntegerToString(i), OBJPROP_TEXT, "|"+DoubleToString(dTemp, 2));

         next+=27;
      }
   }

   if(!IsTesting() || (IsTesting() && IsVisualMode()))
   {
      int Yt[3]={50, 350, 200}, Xt[3]={110, 110, 110};
      color textColor=White;

      ObjectCreateEx("_Benefit_t2_body", Yt[1]-30, Xt[1]-5, OBJ_LABEL, 0, true);
      ObjectSetString(0, "_Benefit_t2_body", OBJPROP_TEXT, "ggg");

      ObjectCreateEx("_Benefit_t2_Header", Yt[1]-25, Xt[1]+110, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_Header", OBJPROP_TEXT, "SELL-SIDE");

      ObjectCreateEx("_Benefit_t2_1_1", Yt[1], Xt[1], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_1_1", OBJPROP_TEXT, "Orders: "+IntegerToString(sells));

      ObjectCreateEx("_Benefit_t2_1_2", Yt[1]+15, Xt[1], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_1_2", OBJPROP_TEXT, "Volume: "+DoubleToString(lotsSells, 2));

      ObjectCreateEx("_Benefit_t2_1_3", Yt[1]+30, Xt[1], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_1_3", OBJPROP_TEXT, "TP Level: "+DoubleToString(SellsTP, (int)Digits()));

      ObjectCreateEx("_Benefit_t2_1_4", Yt[1]+45, Xt[1], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_1_4", OBJPROP_TEXT, "LTP Level: "+DoubleToString(LOTSellsTP, (int)Digits()));

      ObjectCreateEx("_Benefit_t2_2_1", Yt[1], Xt[1]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_2_1", OBJPROP_TEXT, "Profit: "+DoubleToString(profitSells, 2));

      ObjectCreateEx("_Benefit_t2_2_3", Yt[1]+15, Xt[1]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t2_2_3", OBJPROP_TEXT, "BE Level: "+DoubleToString(SellsBE, (int)Digits()));

      ObjectCreateEx("_Benefit_t2_2_4", Yt[1]+30, Xt[1]+160, OBJ_LABEL, 0);
      double lotProfit = (historyProfitSells/(AccountInfoDouble(ACCOUNT_BALANCE)-historyProfitSells)*100);
      ObjectSetString(0, "_Benefit_t2_2_4", OBJPROP_TEXT, "Lot Profit: "+DoubleToString(lotProfit, 2)+"%");

      double w1;
      double loclot=0;
      int next=Xt[0];
      int y=Yt[1];
      color col2=textColor;

      for(i=0; i<16; i++)
      {
         j=i-Step_Coef_Start_Order_Sell+2;
         if(j<0) j=0;
         w1=Step_Sell*MathPow(Step_Coef_Sell, j);
         if(NO(Step_Coef_Sell)==0) w1=ParseStepMass(i+1, 1);

         ObjectCreateEx("_Benefit_t2_3_"+IntegerToString(i), y+75, next, OBJ_LABEL, 0);
         col2=textColor;
         if(TotalOrders[1]>=i+1) col2=Tomato;
         dTemp=GetLot(1, i+1);
         loclot+=dTemp;

         ObjectSetString(0, "_Benefit_t2_3_"+IntegerToString(i), OBJPROP_TEXT, "|"+DoubleToString(w1, 0));

         ObjectCreateEx("_Benefit_t2_3L_"+IntegerToString(i), y+90, next, OBJ_LABEL, 0);
         ObjectSetString(0, "_Benefit_t2_3L_"+IntegerToString(i), OBJPROP_TEXT, "|"+DoubleToString(dTemp, 2));

         next+=27;
      }
   }

   if(!IsTesting() || (IsTesting() && IsVisualMode()))
   {
      int Yt[3]={50, 350, 200}, Xt[3]={110, 110, 110};
      color textColor=White;

      ObjectCreateEx("_Benefit_t3_body", Yt[2]-30, Xt[2]-5, OBJ_LABEL, 0, true);
      ObjectSetString(0, "_Benefit_t3_body", OBJPROP_TEXT, "ggg");

      ObjectCreateEx("_Benefit_t3_Header", Yt[2]-25, Xt[2]+0, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_Header", OBJPROP_TEXT, Symbol()+", M"+IntegerToString(Period()));

      string sbase = ":...:...:...:...:";
      int lenbase = StringLen(sbase);
      int sec = (int)(TimeCurrent()-iTime(Symbol(), PERIOD_CURRENT, 0));
      i = (lenbase-1)*sec/(Period()*60);
      double pc = 100.0*sec/(Period()*60);
      if (i>lenbase-1) i = lenbase-1;
      string s_beg="", s_end="";
      if (i>0) s_beg = StringSubstr(sbase,0,i);
      if (i<lenbase-1) s_end = StringSubstr(sbase,i+1,lenbase-i-1);
      if (pc>100) pc=100;
      s_end = StringConcatenate(s_beg,"|",s_end," ",IntegerToString((int)pc),"%");

      ObjectCreateEx("_Benefit_t3_BarTimer", Yt[2]-25, Xt[2]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_BarTimer", OBJPROP_TEXT, s_end);

      ObjectCreateEx("_Benefit_t3_1_1", Yt[2], Xt[2], OBJ_LABEL, 0);
      string tStr="VTP: ON";
      if(!VTP) tStr="VTP: OFF";
      ObjectSetString(0, "_Benefit_t3_1_1", OBJPROP_TEXT, tStr);

      ObjectCreateEx("_Benefit_t3_1_2", Yt[2]+15, Xt[1], OBJ_LABEL, 0);
      tStr="RRS: ON";
      if(!RRS) tStr="RRS: OFF";
      ObjectSetString(0, "_Benefit_t3_1_2", OBJPROP_TEXT, tStr);

      ObjectCreateEx("_Benefit_t3_1_3", Yt[2]+30, Xt[2], OBJ_LABEL, 0);
      double spread = (SymbolInfoDouble(Symbol(),SYMBOL_ASK)-SymbolInfoDouble(Symbol(),SYMBOL_BID))/Point();
      ObjectSetString(0, "_Benefit_t3_1_3", OBJPROP_TEXT, "Spread: "+DoubleToString(spread, 0));

      ObjectCreateEx("_Benefit_t3_1_4", Yt[2]+45, Xt[2], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_1_4", OBJPROP_TEXT, "Min Lot Buy: "+DoubleToString(Min_Lot_Buy, 2));

      ObjectCreateEx("_Benefit_t3_1_5", Yt[2]+60, Xt[2], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_1_5", OBJPROP_TEXT, "Exp Buy: "+DoubleToString(Lot_Exp_Buy, 2));

      ObjectCreateEx("_Benefit_t3_1_6", Yt[2]+75, Xt[2], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_1_6", OBJPROP_TEXT, "Min Lot Sell: "+DoubleToString(Min_Lot_Sell, 2));

      ObjectCreateEx("_Benefit_t3_1_7", Yt[2]+90, Xt[2], OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_1_7", OBJPROP_TEXT, "Exp Sell: "+DoubleToString(Lot_Exp_Sell, 2));

      ObjectCreateEx("_Benefit_t3_2_1", Yt[2], Xt[2]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_2_1", OBJPROP_TEXT, "Balance: "+DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));

      ObjectCreateEx("_Benefit_t3_2_2", Yt[2]+15, Xt[2]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_2_2", OBJPROP_TEXT, "Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));

      ObjectCreateEx("_Benefit_t3_2_3", Yt[2]+30, Xt[2]+160, OBJ_LABEL, 0);
      tStr="Drawdown: 0%";
      if(AccountInfoDouble(ACCOUNT_EQUITY)<AccountInfoDouble(ACCOUNT_BALANCE))
         tStr="Drawdown: "+DoubleToString((AccountInfoDouble(ACCOUNT_BALANCE)-AccountInfoDouble(ACCOUNT_EQUITY))*100/AccountInfoDouble(ACCOUNT_BALANCE), 2)+"%";
      ObjectSetString(0, "_Benefit_t3_2_3", OBJPROP_TEXT, tStr);

      ObjectCreateEx("_Benefit_t3_2_4", Yt[2]+45, Xt[2]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_2_4", OBJPROP_TEXT, "Profit Day: "+DoubleToString(dayProfit, 2));

      ObjectCreateEx("_Benefit_t3_2_5", Yt[2]+60, Xt[2]+160, OBJ_LABEL, 0);
      ObjectSetString(0, "_Benefit_t3_2_5", OBJPROP_TEXT, "Profit Week: "+DoubleToString(weekProfit, 2));

      ObjectCreateEx("_Benefit_t3_2_6", Yt[2]+75, Xt[2]+160, OBJ_LABEL, 0);
      dTemp=GetStopLevel(lotsBuys-lotsSells);
      ObjectSetString(0, "_Benefit_t3_2_6", OBJPROP_TEXT, "StopOut Level: "+DoubleToString(dTemp, (int)Digits()));

      ObjectCreateEx("_Benefit_t3_2_7", Yt[2]+90, Xt[2]+160, OBJ_LABEL, 0);
      tStr=" points up";
      if(dTemp<SymbolInfoDouble(Symbol(),SYMBOL_ASK)) tStr=" points down";
      ObjectSetString(0, "_Benefit_t3_2_7", OBJPROP_TEXT, "Till StopOut "+DoubleToString(MathAbs(dTemp-SymbolInfoDouble(Symbol(),SYMBOL_ASK))/Point(), 0)+tStr);
   }

   //==========================================Trailing
   if(VTP)
   {
      if(TotalOrders[0]>0 && SymbolInfoDouble(Symbol(),SYMBOL_ASK)-BuysTP>Tral_Start && (TrallBuys<0 || SymbolInfoDouble(Symbol(),SYMBOL_ASK)-Tral_Size>TrallBuys))
         TrallBuys=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-Tral_Size;

      if(TotalOrders[1]>0 && SellsTP-SymbolInfoDouble(Symbol(),SYMBOL_BID)>Tral_Start && (TrallSells<0 || SymbolInfoDouble(Symbol(),SYMBOL_BID)+Tral_Size<TrallSells))
         TrallSells=SymbolInfoDouble(Symbol(),SYMBOL_BID)+Tral_Size;

      if(RRS && TotalOrders[0]>=RRS_nOrder && SymbolInfoDouble(Symbol(),SYMBOL_ASK)-LOTBuysTP>RRS_Tral_Start && (LotTrallBuys<0 || SymbolInfoDouble(Symbol(),SYMBOL_ASK)-RRS_Tral_Size>LotTrallBuys))
         LotTrallBuys=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-RRS_Tral_Size;

      if(RRS && TotalOrders[1]>=RRS_nOrder && LOTSellsTP-SymbolInfoDouble(Symbol(),SYMBOL_BID)>RRS_Tral_Start && (LotTrallSells<0 || SymbolInfoDouble(Symbol(),SYMBOL_BID)+RRS_Tral_Size<LotTrallSells))
         LotTrallSells=SymbolInfoDouble(Symbol(),SYMBOL_BID)+RRS_Tral_Size;

      if(!IsTesting() || (IsTesting() && IsVisualMode()))
      {
         if(TrallBuys<0)
            ObjectSetDouble(0, "_Benefit_BuyTrall", OBJPROP_PRICE, 0);
         else
            ObjectSetDouble(0, "_Benefit_BuyTrall", OBJPROP_PRICE, TrallBuys);

         if(TrallSells<0)
            ObjectSetDouble(0, "_Benefit_SellTrall", OBJPROP_PRICE, 0);
         else
            ObjectSetDouble(0, "_Benefit_SellTrall", OBJPROP_PRICE, TrallSells);

         if(LotTrallBuys<0)
            ObjectSetDouble(0, "_Benefit_BuyLOTTrall", OBJPROP_PRICE, 0);
         else
            ObjectSetDouble(0, "_Benefit_BuyLOTTrall", OBJPROP_PRICE, LotTrallBuys);

         if(LotTrallSells<0)
            ObjectSetDouble(0, "_Benefit_SellLOTTrall", OBJPROP_PRICE, 0);
         else
            ObjectSetDouble(0, "_Benefit_SellLOTTrall", OBJPROP_PRICE, LotTrallSells);
      }

      if(SymbolInfoDouble(Symbol(),SYMBOL_ASK)<TrallBuys && TrallBuys>0)
      {
         PutServiceOrder(4, MAGIC+1);
         return;
      }

      if(SymbolInfoDouble(Symbol(),SYMBOL_BID)>TrallSells && TrallSells>0)
      {
         PutServiceOrder(5, MAGIC+1);
         return;
      }

      if(SymbolInfoDouble(Symbol(),SYMBOL_ASK)<LotTrallBuys && LotTrallBuys>0)
      {
         if(posInfo.SelectByTicket(DtI(Orders[0][0][0])))
            trade.PositionClose(posInfo.Ticket());

         if(posInfo.SelectByTicket(DtI(Orders[0][1][0])))
            trade.PositionClose(posInfo.Ticket());

         LotTrallBuys=-1;
      }

      if(SymbolInfoDouble(Symbol(),SYMBOL_BID)>LotTrallSells && LotTrallSells>0)
      {
         if(posInfo.SelectByTicket(DtI(Orders[1][0][0])))
            trade.PositionClose(posInfo.Ticket());

         if(posInfo.SelectByTicket(DtI(Orders[1][1][0])))
            trade.PositionClose(posInfo.Ticket());

         LotTrallSells=-1;
      }
   }

   //==========================================Close grid if RRS profit reached
   if(RRS && (historyProfitBuys+profitBuys)>=(AccountInfoDouble(ACCOUNT_BALANCE)-historyProfitBuys)*RRS_Profit_Percent/100)
   {
      PutServiceOrder(4, MAGIC+1);
      return;
   }

   if(RRS && (historyProfitSells+profitSells)>=(AccountInfoDouble(ACCOUNT_BALANCE)-historyProfitSells)*RRS_Profit_Percent/100)
   {
      PutServiceOrder(5, MAGIC+1);
      return;
   }

   //Modify SL/TP of orders (for ECN)
   if(ECN && !VTP)
      SetSLTPifNULL();

   //==========================================Open orders
   if(Buy && TotalOrders[0]<Max_Trades)
   {
      op=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      if(NO(SL)!=0.0)sl=op-SL;else sl=0;
      if(NO(TP)!=0.0)tp=op+TP;else tp=0;
      if(ECN)
      {
         tp=0;
         sl=0;
      }

      lot=GetLot(0, TotalOrders[0]+1);
      trade.BuyMarket(Lots(lot), Symbol());
   }

   if(Sell && TotalOrders[1]<Max_Trades)
   {
      op=SymbolInfoDouble(Symbol(),SYMBOL_BID);
      if(NO(SL)!=0.0)sl=op+SL;else sl=0;
      if(NO(TP)!=0.0)tp=op-TP;else tp=0;
      if(ECN)
      {
         tp=0;
         sl=0;
      }

      lot=GetLot(1, TotalOrders[1]+1);
      trade.SellMarket(Lots(lot), Symbol());
   }
}

//+------------------------------------------------------------------+
//| Function sets SL/TP for orders if them equal 0. (for ECN Brokers)|
//+------------------------------------------------------------------+
bool SetSLTPifNULL()
{
   double sl,tp;
   for(int i=0;i<TotalOrders[0];i++)
   {
      if(!posInfo.SelectByTicket(DtI(Orders[0][i][0]))) continue;

      if(RRS && i<2 && TotalOrders[0]>=RRS_nOrder)
         tp=LOTBuysTP;
      else
         tp=BuysTP;

      if(NO(sl)!=NO(posInfo.StopLoss()) || NO(tp)!=NO(posInfo.TakeProfit()))
         trade.PositionModify(posInfo.Ticket(), NO(sl), NO(tp));
   }

   for(i=0;i<TotalOrders[1];i++)
   {
      if(!posInfo.SelectByTicket(DtI(Orders[1][i][0]))) continue;

      if(RRS && i<2 && TotalOrders[1]>=RRS_nOrder)
         tp=LOTSellsTP;
      else
         tp=SellsTP;

      if(NO(sl)!=NO(posInfo.StopLoss()) || NO(tp)!=NO(posInfo.TakeProfit()))
         trade.PositionModify(posInfo.Ticket(), NO(sl), NO(tp));
   }
}

//+------------------------------------------------------------------+
//| Normalize Double                                                  |
//+------------------------------------------------------------------+
double NO(double pp)
{
   return(NormalizeDouble(pp, (int)Digits()));
}

//+------------------------------------------------------------------+
//| Returns normalized Lot amount                                     |
//+------------------------------------------------------------------+
double Lots(double initialLot)
{
   double lot;
   if(initialLot==-1)
      return(-1);
   lot=NormalizeDouble(initialLot,2);

   lot=MathMin(SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX), lot);
   lot=MathMax(SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN), lot);

   if(lot>Max_Lot) lot=Max_Lot;
   return(NormalizeDouble(lot,2));
}

//+------------------------------------------------------------------+
//| Convert Double to Integer                                         |
//+------------------------------------------------------------------+
int DtI(double digit)
{
   return((int)digit);
}

//+------------------------------------------------------------------+
//| Get Stop Level                                                   |
//+------------------------------------------------------------------+
double GetStopLevel(double dLots)
{
   if(NO(dLots)==0.0) return(0);

   double freemargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double tickvalue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double stop_out = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

   double dZM = freemargin / (tickvalue * dLots);
   double dZF = equity / (tickvalue * dLots);
   double dDZ = dZF - dZM;
   double dSO = dZF - dDZ * stop_out / 100;
   double UrSO = 0.0;

   if (dLots > 0) UrSO = SymbolInfoDouble(Symbol(),SYMBOL_BID) - dSO * Point();
   if (dLots < 0) UrSO = SymbolInfoDouble(Symbol(),SYMBOL_ASK) - dSO * Point();

   if(dLots != 0.0)
      return(UrSO);

   return(0);
}

//+------------------------------------------------------------------+
//| Get Lot Size                                                      |
//+------------------------------------------------------------------+
double GetLot(int posType, int orderNumber)
{
   double llot=0;

   if(posType==0)
   {
      llot=Min_Lot_Buy*MathPow(Lot_Exp_Buy, orderNumber-2);
      if(orderNumber<=2) llot=Min_Lot_Buy;
   }

   if(posType==1)
   {
      llot=Min_Lot_Sell*MathPow(Lot_Exp_Sell, orderNumber-2);
      if(orderNumber<=2) llot=Min_Lot_Sell;
   }
   return(llot);
}

//+------------------------------------------------------------------+
//| Put Service Order                                                 |
//+------------------------------------------------------------------+
bool PutServiceOrder(int orderType, int mmagic)
{
   double op, sl, tp;
   double priceRange=500;

   if(orderType==2)
   {
      op=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-priceRange*Point()*x;
      sl=op-25*Point()*x;
      tp=op+25*Point()*x;
      if(ECN) {sl=0;tp=0;}
   }

   if(orderType==5)
   {
      op=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-priceRange*Point()*x;
      sl=op+25*Point()*x;
      tp=op-25*Point()*x;
      if(ECN){sl=0;tp=0;}
   }

   if(orderType==4)
   {
      op=SymbolInfoDouble(Symbol(),SYMBOL_ASK)+priceRange*Point()*x;
      sl=op-25*Point()*x;
      tp=op+25*Point()*x;
      if(ECN){sl=0;tp=0;}
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Point Cost                                                        |
//+------------------------------------------------------------------+
double PointCost(double lotes)
{
   double StoimTik=SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_VALUE)/(SymbolInfoDouble(Symbol(),SYMBOL_TRADE_TICK_SIZE)/Point())/100;
   double count=NormalizeDouble(lotes/0.01,2);
   double value=NormalizeDouble(count*StoimTik,2);
   if(NO(value)==0.00) value=0.01;
   return(value);
}

//+------------------------------------------------------------------+
//| Parse Step Mass                                                  |
//+------------------------------------------------------------------+
double ParseStepMass(int till, int type)
{
   if(till==0) return(0);

   int pos=0, newPos=0;
   int step=0;
   string mass=Step_Mass_Buy+",";
   if(type==1) mass=Step_Mass_Sell+",";

   for(int i=1; i<=till; i++)
   {
      pos=StringFind(mass, ",", newPos);
      if(pos<0) break;
      step=(int)StringToInteger(StringSubstr(mass, newPos, pos-newPos));
      newPos=pos+1;
   }

   if(step<=0) Alert("Error! Step=0");

   return(step);
}

//+------------------------------------------------------------------+
//| There is Order on This Bar                                       |
//+------------------------------------------------------------------+
bool ThereIsOrderOnThisBar(datetime barTime, int posType)
{
   for(int p=PositionsTotal()-1;p>=0;p--)
   {
      if(!posInfo.SelectByIndex(p)) continue;
      if(posInfo.Magic()!=MAGIC) continue;
      if(posInfo.Symbol()!=Symbol()) continue;

      if(posInfo.PositionType()!=posType) continue;
      if(posInfo.Time()>=barTime) return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| EA deinitialization function                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string oName=ObjectName(0, i);
      if(StringFind(oName, "_Benefit")>-1)
         ObjectDelete(0, oName);
   }
}
