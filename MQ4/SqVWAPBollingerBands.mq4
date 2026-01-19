//+------------------------------------------------------------------+
//|                                          SqVWAPBollingerBands.mq4|
//|                            Copyright © @2023 StrategyQuant s.r.o.|
//|                                     http://www.strategyquant.com |
//+------------------------------------------------------------------+
#property  copyright "Copyright © Clonex @2023 StrategyQuant s.r.o."
#property  link      "https://strategyquant.com/?irgwc=1"

//---- indicator settings
#property  indicator_chart_window;
#property  indicator_buffers 3

#property indicator_color1 DeepSkyBlue
#property indicator_style1 0
#property indicator_width1 2

#property indicator_color2 DeepSkyBlue
#property indicator_style2 0
#property indicator_width2 2


#property indicator_color3 Red
#property indicator_style3 0
#property indicator_width3 2

//----
extern int VWAPPeriod=10;
extern double  Deviation= 2.0;

//---- buffers
double IndiBuffer[];
double Upper[];
double Lower[];

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int init()
  {

   
   SetIndexStyle(0,DRAW_LINE);
   SetIndexStyle(1,DRAW_LINE);
   SetIndexStyle(2,DRAW_LINE);
   
   
   SetIndexBuffer(0,Upper,INDICATOR_DATA);
   SetIndexBuffer(1,Lower,INDICATOR_DATA);
   SetIndexBuffer(2,IndiBuffer,INDICATOR_DATA);
   
   SetIndexDrawBegin(0,VWAPPeriod);
   IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS)+2);
   
   IndicatorShortName("SqVWAPBollingerBands("+VWAPPeriod+";"+Deviation+")");
   
   
   SetIndexLabel(0,"VWAP BB Upper");
   SetIndexLabel(1,"VWAP BB Lower");
   SetIndexLabel(2,"VWAP ");


   return(0);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int start()
  {
  	

   int i, limit;
   int counted_bars=IndicatorCounted();
   if(counted_bars>0)
      counted_bars--;
   limit=Bars-counted_bars;

   for(i=limit; i>=0; i--)
     {
      double ohlcAvg = 0;
      double vol =0;
      double __ohlcvTotal = 0;
      double __volumeTotal = 0;

      for(int p = 0; p< VWAPPeriod; p++){
           
      ohlcAvg = (Open[i+p]+High[i+p]+Low[i+p]+Close[i+p])/4;
      vol = Volume[i+p];
           
         __ohlcvTotal = __ohlcvTotal + (ohlcAvg*vol);
			__volumeTotal =__volumeTotal + vol;
      
      }
      

      if(__volumeTotal!=0)double vwap = __ohlcvTotal/__volumeTotal;
      

      IndiBuffer[i] = vwap;


     }
     
     for(i=0; i<limit; i++){ 
     double val=iStdDevOnArray(IndiBuffer,0,VWAPPeriod,i,MODE_SMA,0); 
     Upper[i] = IndiBuffer[i]+val*Deviation;;   
     Lower[i] = IndiBuffer[i]-val*Deviation;; 

   }
    
   return(0);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
