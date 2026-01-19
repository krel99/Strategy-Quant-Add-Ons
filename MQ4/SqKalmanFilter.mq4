//+------------------------------------------------------------------+
//|                                                KalmanFilter.mq4 |
//|     Translation from StrategyQuant Java to MQL4 with 100% sync   |
//+------------------------------------------------------------------+
#property copyright "Copyright (c) 2025, StrategyQuant"
#property link      "https://roadmap.strategyquant.com"
#property version   "1.00"

// Indicator settings:
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_color1  Blue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//===================================================================
// INPUT PARAMETERS
//===================================================================
// These match the Java parameters exactly:
extern double ProcessNoise     = 0.001;  // minValue=0.00001, maxValue=0.1
extern double MeasurementNoise = 0.1;    // minValue=0.01,    maxValue=10
extern double Decay            = 1.0;    // minValue=0.9,     maxValue=1.0

//===================================================================
// INTERNAL BUFFERS
//===================================================================
double KalmanBuffer[];  // output buffer for final Kalman filter value

//===================================================================
// STATE VARIABLES (persist across calls in MQL4)
//===================================================================
// We keep them static so they preserve their values between bar calculations:
static double x;    // Filtered price estimate
static double v;    // Velocity (slope) estimate
static double P00;  // Covariance element (price variance)
static double P01;  // Covariance element (price-velocity covariance)
static double P10;  // Covariance element (velocity-price covariance)
static double P11;  // Covariance element (velocity variance)

// Constants
static double dt = 1.0;        // Always 1.0 per bar
#define PRECISION 5            // Rounding precision for all calculations

//===================================================================
// MQL4 INITIALIZATION
//===================================================================
int init()
{
   IndicatorBuffers(1);
   SetIndexStyle(0, DRAW_LINE);
   SetIndexBuffer(0, KalmanBuffer);

   // Name for the Data Window / Indicator subwindow:
   IndicatorShortName("KalmanFilter(ProcessNoise="+DoubleToStr(ProcessNoise,4)+
                      ", MeasurementNoise="+DoubleToStr(MeasurementNoise,2)+
                      ", Decay="+DoubleToStr(Decay,3)+")");

   return(0);
}

//===================================================================
// MQL4 DEINITIALIZATION
//===================================================================
int deinit()
{
   return(0);
}

//===================================================================
// ONCALCULATE - Processes from oldest bar to newest to mirror SQ’s OnBarUpdate
//===================================================================
int start()
{
   // Number of bars (candles) in the chart
   int rates_total = Bars;

   // If there are not enough bars, do nothing
   if(rates_total < 1) return(0);

   // We'll re-run the entire logic from the oldest bar to the newest bar on every tick
   // so the state transitions match the Java code exactly each time.
   // This means we must reset everything and walk from left (oldest) to right (newest).
   
   // Reset state variables so that the first bar processed is handled like getCurrentBar()==0
   x   = 0.0;
   v   = 0.0;
   P00 = 0.0;
   P01 = 0.0;
   P10 = 0.0;
   P11 = 0.0;

   // Process bars oldest to newest:
   // i = rates_total-1 is the very first historical bar,
   // i = 0 is the most recent (bar 0).
   // We'll invert the loop to mimic OnBarUpdate(0..end).
   for(int i = rates_total-1; i >= 0; i--)
   {
      // "measurement" is the close price for bar i, but we round it to PRECISION
      double measurement = NormalizeDouble(Close[i], PRECISION);

      // For the first bar we process, initialize the filter:
      // (Equivalent to if(getCurrentBar() == 0) in Java code.)
      // Because we're going from old to new, the first iteration is i=rates_total-1
      if(i == rates_total-1)
      {
         // Initialize state for first bar
         x   = measurement;         // x = first measurement
         v   = 0.0;                 // initial velocity is zero
         P00 = MeasurementNoise;    // initial uncertainty in price
         P01 = 0.0;
         P10 = 0.0;
         P11 = MeasurementNoise;    // initial uncertainty in velocity

         // Store the output in the buffer
         KalmanBuffer[i] = x;
         continue;
      }

      // Otherwise, do the time update + measurement update

      // Apply Decay if < 1.0
      if(Decay < 1.0)
         v = NormalizeDouble(v * Decay, PRECISION);

      // Prediction step
      double x_pred = NormalizeDouble(x + v*dt, PRECISION);
      double v_pred = v;

      // Covariance prediction
      double F00 = 1.0, F01 = dt, F10 = 0.0, F11 = 1.0;
      double Q00 = ProcessNoise;
      double Q01 = 0.0;
      double Q10 = 0.0;
      double Q11 = NormalizeDouble(ProcessNoise * 10.0, PRECISION); // higher velocity uncertainty

      double P00_temp = NormalizeDouble(F00*P00*F00 + F00*P01*F10 + F01*P10*F00 + F01*P11*F10 + Q00, PRECISION);
      double P01_temp = NormalizeDouble(F00*P00*F01 + F00*P01*F11 + F01*P10*F01 + F01*P11*F11 + Q01, PRECISION);
      double P10_temp = NormalizeDouble(F10*P00*F00 + F10*P01*F10 + F11*P10*F00 + F11*P11*F10 + Q10, PRECISION);
      double P11_temp = NormalizeDouble(F10*P00*F01 + F10*P01*F11 + F11*P10*F01 + F11*P11*F11 + Q11, PRECISION);

      // Measurement update
      double y = NormalizeDouble(measurement - x_pred, PRECISION);         // measurement residual
      double S = NormalizeDouble(P00_temp + MeasurementNoise, PRECISION);  // innovation covariance

      // Kalman Gain
      double K0 = (S == 0.0) ? 0.0 : NormalizeDouble(P00_temp / S, PRECISION);
      double K1 = (S == 0.0) ? 0.0 : NormalizeDouble(P10_temp / S, PRECISION);

      // Updated state
      x = NormalizeDouble(x_pred + K0 * y, PRECISION);
      v = NormalizeDouble(v_pred + K1 * y, PRECISION);

      // Updated covariance
      P00 = NormalizeDouble((1.0 - K0)*P00_temp, PRECISION);
      P01 = NormalizeDouble((1.0 - K0)*P01_temp, PRECISION);
      P10 = NormalizeDouble(-K1*P00_temp + P10_temp, PRECISION);
      P11 = NormalizeDouble(-K1*P01_temp + P11_temp, PRECISION);

      // Write the filter's current value into the buffer
      KalmanBuffer[i] = x;
   }

   // Return number of bars processed
   return(rates_total);
}
