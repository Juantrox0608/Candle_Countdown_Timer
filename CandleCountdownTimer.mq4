//+------------------------------------------------------------------+
//|                                  Candle Countdown Timer          |
//|                         Created by: Juan David Caicedo Cuesta      |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property copyright " Candle Countdown Timer "
#property version   "1.07"

// Definition of a constant for the refresh interval in milliseconds
#define Refresh_MilliSeconds 500 // Refresh interval in milliseconds

// Enumeration for Yes/No options, facilitating binary parameter settings
enum YN {No, Yes};

//---------------------------
// Input Parameters
//---------------------------

// User-configurable parameters to customize the appearance and behavior of the indicator
input int bidLineWeight = 2;                // Thickness of the BID line
input color askColor = clrMagenta;          // Color of the ASK line
input YN showAsk = Yes;                     // Show or hide the ASK line
input YN showText = Yes;                    // Show or hide price and time text
input int widthFactor = 4;                  // Line proportion factor
input color TextColor_UP = clrDodgerBlue;   // Color for ascending text
input color TextColor_DN = clrTomato;       // Color for descending text
input color line_UP_color = clrDodgerBlue;  // Color for ascending BID line
input color line_DN_color = clrTomato;      // Color for descending BID line
input color LossColor = Red;                // Color for negative P/L
input color ProfitColor = Blue;             // Color for positive P/L

// Parameters for the Watermark (Overlay Text)
input string watermarkText = "@yennytrader"; // Text for the watermark
input color watermarkColor = clrGray;           // Color of the watermark (simulates semi-transparency)
input int watermarkFontSize = 10;               // Font size for the watermark
input int watermarkCorner = CORNER_RIGHT_LOWER; // Corner where the watermark will be placed
input int watermarkXDistance = 150;              // X distance from the chosen corner
input int watermarkYDistance = 30;               // Y distance from the chosen corner


//---------------------------
// Global Variables
//---------------------------

// Variables to store prices, points, and profit/loss
double last_lineB = 0, last_lineA = 0, myPoint = 0, New_Price, Old_Price;
double totalPL = 0;    // Total Profit/Loss
int totalPips = 0;     // Total Pips
datetime T1, T4;
int Chart_Scale = 0;
color Static_Price_Color, Static_Bid_Color, BidLineColor, Static_BidLineColor,
      _UP_color, _DN_color;

// Variables for Overlay (Text Superimposed on the Chart)
string staticLabel = "StaticText";    // Name for the static text object
string dynamicLabel = "DynamicText";  // Name for the dynamic text object
string watermarkLabel = "WatermarkText"; // Name for the watermark text object

//---------------------------
// Auxiliary Functions
//---------------------------

/**
 * @brief Creates or updates a text object on the chart.
 *
 * @param name Unique name of the object.
 * @param text Text to display.
 * @param x X-coordinate position.
 * @param y Y-coordinate position.
 * @param textColor Color of the text.
 * @param fontSize Font size of the text.
 * @param corner Corner of the chart where the text will be placed.
 * @param isWatermark Optional boolean to identify if it's a watermark.
 * @return true If the object is created or updated successfully.
 * @return false If object creation fails.
 */
bool CreateOrUpdateLabel(string name, string text, int x, int y, color textColor, int fontSize, int corner, bool isWatermark = false)
{
    // Check if the object already exists
    if(ObjectFind(0, name) != -1)
    {
        // Update properties if it exists
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        return true;
    }
    // Create the object if it does not exist
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_BACK, false); // Transparent background
        return true;
    }
    return false; // Failed to create the object
}

/**
 * @brief Updates the text of an existing text object.
 *
 * @param name Name of the object.
 * @param text New text to display.
 */
void UpdateLabel(string name, string text)
{
    if(ObjectFind(0, name) != -1)
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text); // Update the text property
    }
}

/**
 * @brief Generates dynamic overlay text displaying the active currency pair and current timeframe.
 *
 * @return string Dynamic overlay text.
 */
string GetDynamicOverlayText()
{
    string timeframe;
    // Determine the current timeframe and assign its text representation
    switch(Period())
    {
        case PERIOD_M1:
            timeframe = "M1";
            break;
        case PERIOD_M5:
            timeframe = "M5";
            break;
        case PERIOD_M15:
            timeframe = "M15";
            break;
        case PERIOD_M30:
            timeframe = "M30";
            break;
        case PERIOD_H1:
            timeframe = "H1";
            break;
        case PERIOD_H4:
            timeframe = "H4";
            break;
        case PERIOD_D1:
            timeframe = "D1";
            break;
        case PERIOD_W1:
            timeframe = "W1";
            break;
        case PERIOD_MN1:
            timeframe = "MN1";
            break;
        default:
            timeframe = "Unknown";
            break;
    }
    // Return the text combining the active symbol and timeframe
    return "Active Pair: " + Symbol() + " | Timeframe: " + timeframe;
}

/**
 * @brief Creates or updates a trend line on the chart.
 *
 * @param name Unique name of the trend line.
 * @param t1 Time of the first point.
 * @param p1 Price of the first point.
 * @param t2 Time of the second point.
 * @param p2 Price of the second point.
 * @param clr Color of the trend line.
 * @param width Width of the trend line.
 * @param style Style of the trend line (solid, dotted, etc.).
 * @return true If the trend line is created or updated successfully.
 * @return false If trend line creation fails.
 */
bool CreateOrUpdateTrendLine(string name, datetime t1, double p1, datetime t2, double p2, color clr, int width, int style)
{
    // If the trend line does not exist, create it
    if(ObjectFind(0, name) == -1)
    {
        if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
            return false; // Failed to create the trend line
    }
    // Update the coordinates of the trend line
    ObjectSetInteger(0, name, OBJPROP_TIME1, t1);
    ObjectSetDouble(0, name, OBJPROP_PRICE1, p1);
    ObjectSetInteger(0, name, OBJPROP_TIME2, t2);
    ObjectSetDouble(0, name, OBJPROP_PRICE2, p2);

    // Configure the trend line properties
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    return true;
}

/**
 * @brief Deletes all objects on the chart that start with a specific prefix.
 *
 * @param prefix Prefix that object names should start with to be deleted.
 */
void DeleteObjectsByPrefix(string prefix)
{
    for(int i = ObjectsTotal()-1; i >= 0; i--)
    {
        string objName = ObjectName(i);
        if(StringFind(objName, prefix) == 0) // Check if the object name starts with the prefix
        {
            ObjectDelete(objName); // Delete the object
        }
    }
}

/**
 * @brief Determines the point value based on the symbol's digit precision.
 *
 * @param mySymbol Name of the symbol (currency pair) to evaluate.
 * @return double Point value corresponding to the symbol's precision.
 */
double SetPoint(string mySymbol)
{
    // If the symbol has less than 4 digits, the point is 0.01; otherwise, 0.0001
    return (MarketInfo(mySymbol, MODE_DIGITS) < 4) ? 0.01 : 0.0001;
}

/**
 * @brief Sets the visibility of the chart grid.
 *
 * @param value true to show the grid, false to hide it.
 * @param chart_ID ID of the chart (default is 0 for the current chart).
 * @return bool Result of the operation.
 */
bool ChartShowGridSet(const bool value, const long chart_ID = 0)
{
    return ChartSetInteger(chart_ID, CHART_SHOW_GRID, 0, value);
}

/**
 * @brief Retrieves the current scale of the chart.
 *
 * @return int Current chart scale value.
 */
int ChartScaleGet()
{
    long result = -1;
    ChartGetInteger(0, CHART_SCALE, 0, result);
    return ((int)result);
}

/**
 * @brief Calculates the total Profit/Loss (P/L) and total pips from all open orders for the current symbol.
 */
void CalculatePL()
{
    totalPL = 0;    // Reset total Profit/Loss
    totalPips = 0;  // Reset total pips
    int orders = OrdersTotal(); // Get the total number of orders

    // Iterate over all open orders
    for(int i = 0; i < orders; i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) // Select the order by its position
        {
            // Check if the order is for the current symbol and is a buy or sell order
            if(OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL))
            {
                double orderPL = 0;
                int orderPips = 0;

                if(OrderType() == OP_BUY)
                {
                    // Calculate P/L for a buy order
                    orderPL = (Bid - OrderOpenPrice()) * OrderLots() * Point;
                    orderPips = (int)((Bid - OrderOpenPrice()) / Point);
                }
                else if(OrderType() == OP_SELL)
                {
                    // Calculate P/L for a sell order
                    orderPL = (OrderOpenPrice() - Ask) * OrderLots() * Point;
                    orderPips = (int)((OrderOpenPrice() - Ask) / Point);
                }

                totalPL += orderPL;     // Add to total P/L
                totalPips += orderPips; // Add to total pips
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
/**
 * @brief Initialization function for the indicator.
 *
 * @return int Initialization status code.
 */
int OnInit()
{
    // Initialize the timer to update every 500 milliseconds
    EventSetMillisecondTimer(Refresh_MilliSeconds);

    // Set the point value based on the current symbol
    myPoint = SetPoint(Symbol());

    // Initialize BID and ASK lines on the chart with current prices
    placeLineB(Bid);
    placeLineA(Ask);

    // Get the current chart scale
    Chart_Scale = ChartScaleGet();

    // Show the grid on the chart
    ChartShowGridSet(true, 0);

    // Create Overlay (text superimposed on the chart) with static, dynamic, and watermark texts
    // Static Text
    CreateOrUpdateLabel(staticLabel, "Yenny Rodriguez", 150, 10, clrWhite, 12, CORNER_RIGHT_UPPER);

    // Dynamic Text showing the active pair and timeframe
    CreateOrUpdateLabel(dynamicLabel, GetDynamicOverlayText(), 300, 30, clrWhite, 12, CORNER_RIGHT_UPPER);

    // Create Watermark with user-defined parameters
    CreateOrUpdateLabel(watermarkLabel, watermarkText, watermarkXDistance, watermarkYDistance,
                        watermarkColor, watermarkFontSize, watermarkCorner, true);

    return(INIT_SUCCEEDED); // Indicate that initialization was successful
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
/**
 * @brief Deinitialization function for the indicator.
 *
 * @param reason Reason for deinitialization.
 */
void OnDeinit(const int reason)
{
    // Delete BID and ASK lines and associated texts created by the timer
    DeleteObjectsByPrefix("last_bid");   // Delete BID lines
    DeleteObjectsByPrefix("last_ask");   // Delete ASK lines
    DeleteObjectsByPrefix("txt1_");      // Delete associated texts

    // Delete Overlay elements
    ObjectDelete(staticLabel);           // Delete static text
    ObjectDelete(dynamicLabel);          // Delete dynamic text
    ObjectDelete(watermarkLabel);        // Delete watermark
}

//+------------------------------------------------------------------+
//| Timer Function                                                   |
//+------------------------------------------------------------------+
/**
 * @brief Timer function that executes every time the timer triggers (every 500 ms).
 */
void OnTimer()
{
    // Update the dynamic overlay text with current information
    UpdateLabel(dynamicLabel, GetDynamicOverlayText());

    // Optional: Update the Watermark if you want it to vary with zoom
    // In MQL4, there are no direct events to detect zoom changes, so this is limited
    // You could attempt to recreate the watermark here if necessary
}

//+------------------------------------------------------------------+
//| Main Calculation Function                                        |
//+------------------------------------------------------------------+
/**
 * @brief Main calculation function that executes on every price tick.
 *
 * @param rates_total Total number of bars.
 * @param prev_calculated Number of bars calculated previously.
 * @param time Array of bar times.
 * @param open Array of open prices.
 * @param high Array of high prices.
 * @param low Array of low prices.
 * @param close Array of close prices.
 * @param tick_volume Array of tick volumes.
 * @param volume Array of volumes.
 * @param spread Array of spreads.
 * @return int Total number of bars processed.
 */
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Assign ascending and descending line colors to internal variables
    _UP_color = line_UP_color; // Assign ascending line color
    _DN_color = line_DN_color; // Assign descending line color

    // Calculate the new BID price adjusted according to the symbol's digits
    if(Digits > 2)
    {
        // Round down to the nearest multiple of myPoint
        New_Price = MathFloor(Bid / myPoint) * myPoint;
    }
    else
    {
        // If it has 2 or fewer digits, assign the Bid value directly
        New_Price = Bid;
    }

    // Determine the color of the BID line based on price variation
    if(New_Price > Old_Price)
    {
        BidLineColor = _UP_color;           // Price increased, use ascending color
        Static_BidLineColor = BidLineColor;
    }
    else if(New_Price < Old_Price)
    {
        BidLineColor = _DN_color;           // Price decreased, use descending color
        Static_BidLineColor = BidLineColor;
    }
    else
    {
        BidLineColor = Static_BidLineColor; // Price unchanged, maintain previous color
    }
    // Update the old price for the next comparison
    Old_Price = New_Price;

    // Update the BID and ASK lines on the chart with current prices
    placeLineB(Bid);
    placeLineA(Ask);

    return(rates_total); // Return the total number of bars processed
}

//+------------------------------------------------------------------+
//| BID Line                                                         |
//+------------------------------------------------------------------+
/**
 * @brief Draws or updates the BID line on the chart and displays relevant information.
 *
 * @param price Current BID price.
 */
void placeLineB(double price)
{
    // Calculate the remaining time until the current candle closes
    datetime closetime = Time[0] + PeriodSeconds() - TimeCurrent();
    int lineLength = WindowBarsPerChart() / widthFactor; // Determine the length of the line

    // Ensure that lineLength is valid
    if(lineLength < 1)
        lineLength = 1;

    // Calculate the total Profit/Loss (P/L) in currency and pips
    CalculatePL();

    // Format the text to be displayed with price, remaining time, and P/L
    string lineText = "";

    if(OrdersTotal() == 0)
    {
        // If there are no open orders, display that there are no active positions
        lineText = StringConcatenate(
                    "B: ", TimeToStr(closetime, TIME_SECONDS),
                    " ::  No Active Position ");
    }
    else
    {
        // If there are open orders, display remaining time, total P/L, and pips
        lineText = StringConcatenate(
                    "B: ", TimeToStr(closetime, TIME_SECONDS),
                    " :: P/L: ", DoubleToStr(totalPL, 2), " ", AccountCurrency(), " (", totalPips, " pips)"
                 );
    }

    // Determine the points for the BID trend line
    datetime t1 = Time[lineLength];
    double p1 = price;
    datetime t2 = Time[lineLength - 1];
    double p2 = price;

    // Create or update the BID trend line on the chart with the determined parameters
    if(!CreateOrUpdateTrendLine("last_bid", t1, p1, t2, p2, BidLineColor, bidLineWeight, STYLE_SOLID))
    {
        Print("Error creating or updating BID trend line.");
    }

    // Update the text associated with the BID line
    ObjectDelete("txt1_"); // Delete the previous text
    if(showText == Yes)
    {
        // Only display text for timeframes less than or equal to D1
        if(Period() <= PERIOD_D1)
        {
            if(totalPips >= 0)
            {
                // Create and configure the text in ascending color if pips are positive
                if(ObjectCreate("txt1_", OBJ_TEXT, 0, Time[lineLength], price))
                {
                    ObjectSetText("txt1_", lineText, 10, "Arial", TextColor_UP);
                    ObjectSetInteger(0, "txt1_", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
                    ObjectSetInteger(0, "txt1_", OBJPROP_XDISTANCE, 100); // Adjust X position as needed
                    ObjectSetInteger(0, "txt1_", OBJPROP_YDISTANCE, 50);  // Adjust Y position as needed
                }
            }
            else
            {
                // Create and configure the text in descending color if pips are negative
                if(ObjectCreate("txt1_", OBJ_TEXT, 0, Time[lineLength], price))
                {
                    ObjectSetText("txt1_", lineText, 10, "Arial", TextColor_DN);
                    ObjectSetInteger(0, "txt1_", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
                    ObjectSetInteger(0, "txt1_", OBJPROP_XDISTANCE, 100); // Adjust X position as needed
                    ObjectSetInteger(0, "txt1_", OBJPROP_YDISTANCE, 50);  // Adjust Y position as needed
                }
            }
        }
    }
    last_lineB = price; // Update the last BID price
    ChartRedraw();      // Redraw the chart to display changes
}

//+------------------------------------------------------------------+
//| ASK Line                                                         |
//+------------------------------------------------------------------+
/**
 * @brief Draws or updates the ASK line on the chart.
 *
 * @param price Current ASK price.
 */
void placeLineA(double price)
{
    // Determine the length of the line by dividing the number of bars by the width factor
    int lineLength = WindowBarsPerChart() / widthFactor;

    // Ensure that lineLength is valid
    if(lineLength < 1)
        lineLength = 1;

    if(showAsk == Yes) // Check if the ASK line should be displayed
    {
        // Determine the points for the ASK trend line
        datetime t1 = Time[lineLength];
        double p1 = price;
        datetime t2 = Time[lineLength - 6];
        double p2 = price;

        // Ensure that indices are not negative to avoid errors
        if((lineLength - 6) >= 0)
        {
            // Create or update the ASK trend line with a dotted style
            if(!CreateOrUpdateTrendLine("last_ask", t1, p1, t2, p2, askColor, 1, STYLE_DOT))
            {
                Print("Error creating or updating ASK trend line.");
            }
        }
    }
    last_lineA = price; // Update the last ASK price
    ChartRedraw();      // Redraw the chart to display changes
}
//+------------------------------------------------------------------+
