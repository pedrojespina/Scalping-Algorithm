//+------------------------------------------------------------------+
//|                                                       Scalpy.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                     EForT EFST Spring 19    https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict


//+------------------------------------------------------------------+
//|nput parameters and variables                               |
//+------------------------------------------------------------------+

//Exponential Moving Average for 8 period on H1 chart
double EMA_8_H1 ;
//Exponential Moving Average for 21 period on H1 chart
double EMA_21_H1 ;
double RISK ;
double currentHighPrice ;
double currentClosePrice ;
double triggerBarLowPrice ;
double triggerBarHighPrice ;
double currentLowPrice ;
////Exponential Moving Average for 8 period on M5 chart
double EMA_8_M5 ;
////Exponential Moving Average for 13 period on M5 chart
double EMA_13_M5 ;
//Exponential Moving Average for 21 period on M5 chart
double EMA_21_M5 ;
int currentBars ;
int orderTicket ;
//First TakeProfit Target
double takeProfit_1 ;
//Second TakeProfit Target
double takeProfit_2 ;
double trailStop ;
double stopLoss ;
extern double lots = 0.2 ;
// magic number
extern int mn = 555; 
datetime prevtime ;

enum Strategy {twoLevelTP, trailTP} tradingStrategy  ;

enum Trend {NO_TREND, UP_TREND, DOWN_TREND} anchorTrend ;

enum Signal {NO_TRADE, BUY, SELL } tradeSignal ;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}
 
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+  
// Using following build-in functions
//iMA - Calcculates the Moving Average indicator and returns its value.
//double  iMA(
//   string       symbol,           // Symbol name on the data of which the indicator will be calculated. NULL means the current symbol.
//   int          timeframe,        // timeframe, it can be any of enumeration values. 0 means the current timeframe (PERIOD_M1,PERIOD_M5,etc)
//   int          ma_period,        // MA averaging period for calculation
//   int          ma_shift,         // MA shift. Indicators line offset relate to the chart by timeframe.
//   int          ma_method,        // averaging method (MODE_SMA: Simple averaging; MODE_EMA: Exponential averaging; MODE_SMMA: Smoothed averaging; MODE_LWMA: Linear-weighted averaging)
//   int          applied_price,    // applied price (PRICE_CLOSE, PRICE_OPEN, PRICE_MEDIAN, etc)
//   int          shift             // shift.  Index of the value taken from the indicator buffer (shift relative to the current bar the given amount of periods ago).
//   );
// double Close[]
//Series array that contains close prices for each bar of the current chart.
//double Low[]
//Series array that contains the low prices of each bar of the current chart.
//double High[]
//Series array that contains the high prices of each bar of the current chart.
// iHighest - Returns the highest index on a specific number of bars 
// double iHighest(
//    string    symbol,
//    int       timeframe,
//    int       type,
//    int       count,
//    int       start
// )
// iLowest - Returns the lowest value on a specific number of bars 
// double iLowest(
//    string    symbol,
//    int       timeframe,
//    int       type,
//    int       count,
//    int       start
// )
// OrderSend - The main function used to open an order or place a pending order
 // int OrderSend(
 //    string   symbol,
 //    int      cmd,           //operation
 //    double   volume,        // Number of lots
 //    double   price,         //Order price
 //    int      sllippage,     //  MAximum price slippage for buy or sell orders
 //    double   stoploss,
 //    string   comment=NULL,
 //    int      magic=0,       // Order magic number. Maybe used as user defined identifier
 //    datetime expiration=0,
 //    color    arrow_color=clrNone
 // )
 // OrderSend returns number of the ticket assigned to the order by the trade server or -1 if it fails.
 int start()
 {// Time[0] is a series array that contains open time of each bar of the current chart.
 
   //Print("Inside Start") ;
   
   Print("tradingStrategy = ", tradingStrategy) ;
   
   if (! IsTradeAllowed()) { // Checks if the Expert Advisor is allowed to trade and trading context is not busy.
      again(); // pass and try again
      return(0);
   }
   
   /*currentBars = Bars ;
   Print("Current Bars = ", currentBars) ;
   
   if ( currentBars < 21 )
   {
      again() ;
      return(0);
   } */
   
   getAnchorTrend() ;
   getTradeSignal(anchorTrend) ;
   
   Print("tradeSignal = ", tradeSignal) ;
  
   if ( tradeSignal == SELL )
   {
        int index = iLowest(NULL,0,MODE_LOW,5,1);
        double lowestOfLastFive = Low[index] ; 
        Print("towestOfLastFive = ", lowestOfLastFive) ;
     
        triggerBarHighPrice = High[0] ;
        //Print("triggerBarHighPrice = ", triggerBarHighPrice) ;
	//calculate the value of Lowest Low price of the last 5 bars (from the 1th to the 5th index)
	//For 5 digit trade, 10 point = 1 pip 
        double tradeExecutionPrice = lowestOfLastFive - 30*Point ;
        //Print("tradeExecutionPrice = ", tradeExecutionPrice) ; 
        stopLoss = triggerBarHighPrice + 30*Point ;
        //Print("stopLoss = ", stopLoss) ;
        RISK = stopLoss - tradeExecutionPrice ; 
        //Print("RISK = ", RISK) ;
        takeProfit_1 = tradeExecutionPrice - RISK ;
        //Print("takeProfit_1 = ", takeProfit_1) ;
        takeProfit_2 = tradeExecutionPrice - 2*RISK ;
        //Print("takeProfit_2 = ", takeProfit_2) ;
	// we place two orders with same stoploss, sellstop, different take profit.  
        int ticket_1 = OrderSend(Symbol(), OP_SELLSTOP, lots, tradeExecutionPrice, 5, stopLoss, takeProfit_1, "Sell order", mn, 0, Red);
        if (ticket_1 < 0 )
        {
            again() ;
            return(0) ;
        }
        int ticket_2 = OrderSend(Symbol(), OP_SELLSTOP, lots, tradeExecutionPrice, 5, stopLoss, takeProfit_2, "Sell order", mn, 0, Pink);
        if (ticket_2 < 0 )
        {
              again() ;
              return(0) ;
        }
        if ( tradingStrategy == twoLevelTP )
        {
	//if the close price for the current bar reaches the first take profit, the first order will close automatically, 
	//we then set the new stop loss to sellstop for the second order
            if (  Close[0] < takeProfit_1 )
            {
                 OrderModify(ticket_2, takeProfit_1 , tradeExecutionPrice, takeProfit_2, 0, Pink ) ;
            }
            return (0) ;
        }
        if ( tradingStrategy == trailTP )
        { 
            
            if (  Close[0] < takeProfit_1 )
            {
               double stopLossLevel = stopLoss ;
               double takeProfitLevel = takeProfit_2 ;  
               do 
               {
		   // find the index of the highest high price among the last three bars
                  int index= iHighest(NULL,0,MODE_HIGH,3,1);
                  double highestOfTheLastThree = High[index]
                  stopLossLevel = highestOfTheLastThree + 30*Point ;
                  takeProfitLevel -= takeProfitLevel ;
                  OrderModify(ticket_2, takeProfit_1,stopLossLevel, takeProfitLevel, 0, Pink ) ;
               }
               while ( Close[0] < stopLossLevel ) ;
               
            }
        }
    }  
    else if ( tradeSignal == BUY )  
    {
        int index = iHighest(NULL,0,MODE_HIGH,5,1);
        double highestOfLastFive = High[index] ; 
        Print("highestOfLastFive = ", highestOfLastFive) ;
        
        triggerBarLowPrice = Low[0] ;
        //Print("triggerBarLowPrice = ",  triggerBarLowPrice) ;
        //calculate the value of highest high price of the last 5 bars (from the 1th to the 6th index)
        //For 5 digit trade, 10 point = 1 pip 
        double tradeExecutionPrice = highestOfLastFive + 30*Point ;
        //Print("tradeExecutionPrice = ",  tradeExecutionPrice) ; 
        stopLoss = triggerBarLowPrice - 30*Point ;
        //Print("stopLoss = ",  stopLoss) ; 
        RISK = tradeExecutionPrice - stopLoss ; 
        //Print("RISK = ",  RISK) ; 
        takeProfit_1 = tradeExecutionPrice + RISK ;
        //Print("takeProfit_1 = ",  takeProfit_1) ; 
        takeProfit_2 = tradeExecutionPrice + 2*RISK ;
        //Print("takeProfit_2 = ",  takeProfit_2) ; 
	// we place two orders with same stoploss, buystop, different take profit.
        int ticket = OrderSend(Symbol(), OP_BUYSTOP, lots, tradeExecutionPrice, 5, stopLoss, takeProfit_1,"Buy order", mn, 0, Blue);
        if (ticket == -1 )
        {
           again() ;
           return(0) ;
        }
        int ticket_2 = OrderSend(Symbol(), OP_BUYSTOP, lots, tradeExecutionPrice, 5, stopLoss, takeProfit_2, "Buy order", mn, 0, Violet);
        if (ticket_2 < 0 )
        {
              again() ;
              return(0) ;
        }
        if ( tradingStrategy == twoLevelTP )
        {
	//if the close price for the current bar reaches the first take profit, the first order will close automatically, 
	//we then set the new stop loss to buystop for the second order
            if (  Close[0] > takeProfit_1 )
            {
                 OrderModify(ticket_2, takeProfit_1 , tradeExecutionPrice, takeProfit_2, 0, Violet ) ;
            }
            return (0) ;
        }
        if ( tradingStrategy == trailTP )
        { 
            
            if (  Close[0] > takeProfit_1 )
            {
               double stopLossLevel = stopLoss ;
               double takeProfitLevel = takeProfit_2 ;  
               do 
               {
		  // find the index of the lowest low price among the last three bars
                  int index = iLowest(NULL,0,MODE_LOW,3,1);
		   double lowestOfTheLastThree = Low[index]
                  stopLossLevel = lowestOfTheLastThree - 30*Point ;
                  takeProfitLevel = takeProfitLevel*2 ;
                  OrderModify(ticket_2, takeProfit_1,stopLossLevel, takeProfitLevel, 0, Violet ) ;
               }
               while ( Close[0] > stopLossLevel ) ;
               
            }
        }
   }
   /*int total = OrdersTotal();
   Print("total orders = ", total) ;
   for (int i = 0; i < total; i++) {
   OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
   if (OrderSymbol() == Symbol() && OrderMagicNumber() == mn) return(0);
   } */
   return (0) ;
}   

//+------------------------------------------------------------------+
//| again function                                              |
//+------------------------------------------------------------------+   
void again() {
   prevtime = Time[1];
   Sleep(5);
}  

//+------------------------------------------------------------------+
//| getAnchorTrend function                                              |
//+------------------------------------------------------------------+ 
int getAnchorTrend()
{
// calculate the exponential moving average (period 8 and 21) for H1 chart 
   EMA_8_H1 = iMA(NULL, PERIOD_H1 , 8 , 0, MODE_EMA, PRICE_CLOSE, 0 ) ;
   EMA_21_H1 = iMA(NULL, PERIOD_H1 , 21 , 0, MODE_EMA, PRICE_CLOSE, 0 ) ;
   
// Determine the trend by comparing the iMA(8) and iMA(21) on hourly chart
   if ( EMA_8_H1 < EMA_21_H1 )
   {
      anchorTrend = DOWN_TREND ;
   }
   else if ( EMA_8_H1 > EMA_21_H1 )
   {
      anchorTrend = UP_TREND ;
   }
   else
   {
      anchorTrend = NO_TREND ;
   }
   return(0) ;
   
}

//+------------------------------------------------------------------+
//| getTradeSignal function                                              |
//+------------------------------------------------------------------+
int getTradeSignal(int trend)
{
// calculate the exponential moving average (period 8, 13 and 21) for M5 chart
   EMA_8_M5 = iMA(NULL, PERIOD_M5 , 8 , 0, MODE_EMA, PRICE_CLOSE, 0 ) ;
   EMA_13_M5 = iMA(NULL, PERIOD_M5 , 13 , 0, MODE_EMA, PRICE_CLOSE, 0 ) ;
   EMA_21_M5 = iMA(NULL, PERIOD_M5 , 21 , 0, MODE_EMA, PRICE_CLOSE, 0 ) ;
// calculate the close price, high_price and low_price for the current bar
   currentHighPrice = High[0] ;
   currentClosePrice = Close[0] ;
   currentLowPrice = Low[0] ;
// Determine the sell/buy signal by calculating the iMA(8) and iMA(13) and iMA(21) on 5 minutes chart
// If the currentClosePrice is less than EMA_21_M5 when there is down_trend or currentClosePrice is larger than EMA_21_M5 when there is up_trend, the trade is invalid.
   if ( trend == DOWN_TREND )
   {
      if ( EMA_8_M5 < EMA_13_M5 && EMA_13_M5 < EMA_21_M5 )
      {
         if ( currentClosePrice > EMA_8_M5 && currentClosePrice < EMA_21_M5 )
         {
            tradeSignal = SELL ;
         }
         else
         {
            tradeSignal = NO_TRADE ;
         }
      }
   }
   else if ( trend == UP_TREND )
   {
      if ( EMA_8_M5 > EMA_13_M5 && EMA_13_M5 > EMA_21_M5 )
      {
         if ( currentClosePrice < EMA_8_M5 && currentClosePrice > EMA_21_M5 )
         {
            tradeSignal = BUY ;
         }
         else
         {
            tradeSignal = NO_TRADE ;
         }
      }
   }
   else
   {
      tradeSignal = NO_TRADE ;
   }
   return(0) ;
 } 