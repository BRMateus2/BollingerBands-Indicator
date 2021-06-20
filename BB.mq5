//+------------------------------------------------------------------+
//|                                                           BB.mq5 |
//|                   Copyright 2009-2020, MetaQuotes Software Corp. |
//|                   NOT ORIGINAL SOURCE, MODIFIED BY COMMUNITY USER|
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2009-2020, MetaQuotes Software Corp."
#property link        "http://www.mql5.com"
#property description "Bollinger Bands.\n"
#property description "NOT ORIGINAL SOURCE, MODIFIED BY COMMUNITY USER"
#property version "1.00"
//---
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLightSeaGreen
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLightSeaGreen
#property indicator_label1  "Bands middle"
#property indicator_label2  "Bands upper"
#property indicator_label3  "Bands lower"
// Metatrader 5 has a limitation of 64 User Input Variable description, for reference this has 64 traces ----------------------------------------------------------------
//---- Definitions
//#define INPUT const
#ifndef INPUT
#define INPUT input
#endif
//--- input parametrs
INPUT int     InpBandsPeriod = 20;     // Period
INPUT int     InpBandsShift = 0;       // Shift
INPUT double  InpBandsDeviations = 2.0; // Deviation
INPUT bool    InpShowPercentage = true; // Show Percentage to Target on Labels, instead of Absolute values
INPUT ENUM_APPLIED_PRICE ENUM_APPLIED_PRICEInp = PRICE_CLOSE; // Applied Price Equation
INPUT ENUM_MA_METHOD ENUM_MA_METHODInp = MODE_SMA; // Applied Moving Average Method
//---- "Adaptive Period"
input group "Adaptive Period"
INPUT bool InpPeriodAd = true; // Adapt the Period to attempt to match a given higher setting?
INPUT int InpPeriodAdMinutes = 55200; // Period in minutes that all M and H timeframes should adapt to?
INPUT int InpPeriodAdD1 = 40; // Period for D1 - Daily Timeframe
INPUT int InpPeriodAdW1 = 8; // Period for W1 - Weekly Timeframe
INPUT int InpPeriodAdMN1 = 2; // Period for MN - Monthly Timeframe
//--- global variables
int           ExtBandsPeriod, ExtBandsShift;
double        ExtBandsDeviations;
int           ExtPlotBegin = 0;
//--- indicator buffer
double        ExtMLBuffer[];
double        ExtTLBuffer[];
double        ExtBLBuffer[];
double        ExtStdDevBuffer[];
int           maHandle = 0;
//---- PlotIndexSetString() Timer
datetime last = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
//--- check for input values
    if(InpPeriodAd == true) { // Calculate a_period if InpPeriodAd == true. Adaptation works flawless for less than D1 - D1, W1 and MN1 are a constant set by the user.
        if((PeriodSeconds(PERIOD_CURRENT) < PeriodSeconds(PERIOD_D1)) && (PeriodSeconds(PERIOD_CURRENT) >= PeriodSeconds(PERIOD_M1))) {
            if(InpPeriodAdMinutes > 0) {
                ExtBandsPeriod = ((InpPeriodAdMinutes * 60) / PeriodSeconds(PERIOD_CURRENT));
                if(ExtBandsPeriod == 0) {
                    ExtBandsPeriod = ExtBandsPeriod + 1;
                } else if(ExtBandsPeriod < 0) {
                    Print("calculation error with \"ExtBandsPeriod = ((InpPeriodAdMinutes * 60) / PeriodSeconds(PERIOD_CURRENT))\"");
                }
            } else {
                Print("wrong value for \"InpPeriodAdMinutes\" = \"" + IntegerToString(InpPeriodAdMinutes) + "\". Indicator will use value \"" + IntegerToString(InpBandsPeriod) + "\" for calculations.");
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_D1)) {
            if(InpPeriodAdD1 > 0) {
                ExtBandsPeriod = InpPeriodAdD1;
            } else {
                Print("wrong value for \"InpPeriodAdD1\" = \"" + IntegerToString(InpPeriodAdD1) + "\". Indicator will use value \"" + IntegerToString(InpBandsPeriod) + "\" for calculations.");
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_W1)) {
            if(InpPeriodAdW1 > 0) {
                ExtBandsPeriod = InpPeriodAdW1;
            } else {
                Print("wrong value for \"InpPeriodAdW1\" = \"" + IntegerToString(InpPeriodAdW1) + "\". Indicator will use value \"" + IntegerToString(InpBandsPeriod) + "\" for calculations.");
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_MN1)) {
            if(InpPeriodAdMN1 > 0) {
                ExtBandsPeriod = InpPeriodAdMN1;
            } else {
                Print("wrong value for \"InpPeriodAdMN1\" = \"" + IntegerToString(InpPeriodAdMN1) + "\". Indicator will use value \"" + IntegerToString(InpBandsPeriod) + "\" for calculations.");
            }
        } else {
            Print("untreated condition");
        }
    }
    if(InpBandsPeriod < 2 && InpPeriodAd == false) {
        ExtBandsPeriod = 20;
        PrintFormat("Incorrect value for input variable InpBandsPeriod=%d. Indicator will use value=%d for calculations.", InpBandsPeriod, ExtBandsPeriod);
    } else if(InpPeriodAd == false) {
        ExtBandsPeriod = InpBandsPeriod;
    }
    if(InpBandsShift < 0) {
        ExtBandsShift = 0;
        PrintFormat("Incorrect value for input variable InpBandsShift=%d. Indicator will use value=%d for calculations.", InpBandsShift, ExtBandsShift);
    } else
        ExtBandsShift = InpBandsShift;
    if(InpBandsDeviations == 0.0) {
        ExtBandsDeviations = 2.0;
        PrintFormat("Incorrect value for input variable InpBandsDeviations=%f. Indicator will use value=%f for calculations.", InpBandsDeviations, ExtBandsDeviations);
    } else
        ExtBandsDeviations = InpBandsDeviations;
// Treat maHandle
    maHandle = iMA(Symbol(), Period(), ExtBandsPeriod, 0, ENUM_MA_METHODInp, ENUM_APPLIED_PRICEInp);
    if(maHandle == INVALID_HANDLE || maHandle < 0) {
        Print("ERROR: maHandle == INVALID_HANDLE || maHandle < 0");
        return INIT_FAILED;
    }
//--- define buffers
    SetIndexBuffer(0, ExtMLBuffer);
    SetIndexBuffer(1, ExtTLBuffer);
    SetIndexBuffer(2, ExtBLBuffer);
    SetIndexBuffer(3, ExtStdDevBuffer, INDICATOR_CALCULATIONS);
//--- set index labels
    PlotIndexSetString(0, PLOT_LABEL, "Bands Middle");
    PlotIndexSetString(1, PLOT_LABEL, "Bands Upper");
    PlotIndexSetString(2, PLOT_LABEL, "Bands Lower");
//--- indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Bollinger Bands(" + string(ExtBandsPeriod) + ")");
//--- indexes draw begin settings
    ExtPlotBegin = ExtBandsPeriod - 1;
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtBandsPeriod);
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtBandsPeriod);
    PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtBandsPeriod);
//--- indexes shift settings
    PlotIndexSetInteger(0, PLOT_SHIFT, ExtBandsShift);
    PlotIndexSetInteger(1, PLOT_SHIFT, ExtBandsShift);
    PlotIndexSetInteger(2, PLOT_SHIFT, ExtBandsShift);
//--- number of digits of indicator value
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Bollinger Bands                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double& price[])
{
    if(rates_total < ExtPlotBegin)
        return 0;
//--- indexes draw begin settings, when we've recieved previous begin
    if(ExtPlotBegin != ExtBandsPeriod + begin) {
        ExtPlotBegin = ExtBandsPeriod + begin;
        PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, ExtPlotBegin);
        PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, ExtPlotBegin);
        PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, ExtPlotBegin);
    }
//--- starting calculation
    int pos = (prev_calculated > 1) ? (prev_calculated - 1) : 0;
//--- main cycle
    int i = pos;
    //--- middle line
    if(CopyBuffer(maHandle, 0, 0, (rates_total - prev_calculated + 1), ExtMLBuffer) <= 0) { // Try to copy, if there is no data copied for some reason, then we don't need to calculate - also, we don't need to copy rates before prev_calculated as they have the same result
        Print("ERROR: maHandle, 0, 0, (rates_total - prev_calculated + 1), ExtMLBuffer) <= 0");
        return 0;
    }
    for(; i < rates_total && !IsStopped(); i++) {
        //--- calculate and write down StdDev
        ExtStdDevBuffer[i] = StdDev_Func(i, price, ExtMLBuffer, ExtBandsPeriod);
        //--- upper line
        ExtTLBuffer[i] = ExtMLBuffer[i] + ExtBandsDeviations * ExtStdDevBuffer[i];
        //--- lower line
        ExtBLBuffer[i] = ExtMLBuffer[i] - ExtBandsDeviations * ExtStdDevBuffer[i];
    }
//--- Change Plot Name
    if(i == rates_total && last < TimeCurrent()) {
        last = TimeCurrent();
        if(InpShowPercentage) {
            PlotIndexSetString(0, PLOT_LABEL, "Bands Middle (" + DoubleToString((ExtMLBuffer[i - 1] * 100.0 / MathAbs(price[i - 1]) - 100.0), 2) + "%)");
            PlotIndexSetString(1, PLOT_LABEL, "Bands Upper (" + DoubleToString((ExtTLBuffer[i - 1] * 100.0 / MathAbs(price[i - 1]) - 100.0), 2) + "%)");
            PlotIndexSetString(2, PLOT_LABEL, "Bands Lower (" + DoubleToString((ExtBLBuffer[i - 1] * 100.0 / MathAbs(price[i - 1]) - 100.0), 2) + "%)");
        } else {
            PlotIndexSetString(0, PLOT_LABEL, "Bands Middle (" + DoubleToString(ExtMLBuffer[i - 1] - price[i - 1], Digits()) + ")");
            PlotIndexSetString(1, PLOT_LABEL, "Bands Upper (" + DoubleToString(ExtTLBuffer[i - 1] - price[i - 1], Digits()) + ")");
            PlotIndexSetString(2, PLOT_LABEL, "Bands Lower (" + DoubleToString(ExtBLBuffer[i - 1] - price[i - 1], Digits()) + ")");
        }
    }
//--- OnCalculate done. Return new prev_calculated.
    return rates_total;
}
//+------------------------------------------------------------------+
//| Calculate Standard Deviation                                     |
//+------------------------------------------------------------------+
inline double StdDev_Func(const int position, const double & price[], const double & ma_price[], const int period)
{
    double std_dev = 0.0;
//--- calcualte StdDev
    if(position >= period) {
        for(int i = 0; i < period; i++)
            std_dev += MathPow(price[position - i] - ma_price[position], 2.0);
        std_dev = MathSqrt(std_dev / period);
    }
//--- return calculated value
    return std_dev;
}
//+------------------------------------------------------------------+
