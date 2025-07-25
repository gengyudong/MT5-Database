//+------------------------------------------------------------------+
//|                                                   DataSender.mq5 |
//|                                      Copyright 2025, T3 Trading. |
//|                                            https://www.t3.group/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, T3 Trading."
#property link      "https://www.t3.group/"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
string backendBaseURL = "http://127.0.0.1:8000";
string sendOrdersDataEndpoint = "/order";
string sendDealsDataEndpoint = "/deal";
string sendAccountDataEndpoint = "/account";
string sendPositionsDataEndpoint = "/position";

int ordersUpdateInterval = 10; // 10 sec
int accountUpdateInterval = 10; // 1 min
int dealsUpdateInterval = 10; // 1 hour
int dealsUpdateBuffer = 300; // Buffer time in seconds to account for latency or delays
int positionsUpdateInterval = 10; // 1 min

datetime lastAccountUpdate = 0;
datetime lastOrdersUpdate = 0;
datetime lastDealsUpdate = 0;
datetime lastPositionsUpdate = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Initial data send
    sendAccountData();
    sendOrdersData();
    sendDealsData();
    sendPositionsData();
    
    Print("Pinging backend...");
    sendToBackend(backendBaseURL + "/ping", "{}");
    
    datetime lastAccountUpdate = TimeLocal();
    Print(lastAccountUpdate);
    
    datetime lastOrdersUpdate = TimeLocal();
    Print(lastOrdersUpdate);
    
    datetime lastDealsUpdate = TimeLocal();
    Print(lastDealsUpdate);
    
    datetime lastPositionsUpdate = TimeLocal();
    Print(lastPositionsUpdate);
    
    Print("Init Success");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    datetime currentTime = TimeLocal();
    
    // Send open orders data based on stipulated update intervals
    if (currentTime - lastOrdersUpdate >= ordersUpdateInterval) {
        Print("Time to send open order data");
        sendOrdersData();
        lastOrdersUpdate = currentTime;
    }
    
    // Send account data based on stipulated update intervals
    if (currentTime - lastAccountUpdate>= accountUpdateInterval) {
        Print("Time to send account data");
        sendAccountData();
        lastAccountUpdate = currentTime;
    }
    
    // Send close orders data based on stipulated update intervals
    if (currentTime - lastDealsUpdate >= dealsUpdateInterval) {
        Print("Time to send close order data");
        sendDealsData();
        lastDealsUpdate = currentTime;
    }
    
    // Send positions data based on stipulated update intervals
    if (currentTime - lastPositionsUpdate >= positionsUpdateInterval) {
        Print("Time to send positions data");
        sendPositionsData();
        lastPositionsUpdate = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Send HTTP POST request                                           |
//+------------------------------------------------------------------+
void sendToBackend(string url, string data)
{
    char postData[];
    StringToCharArray(data, postData, 0, StringLen(data));
    
    char resultData[];
    string resultHeaders;
    
    ResetLastError();
    int response = WebRequest(
        "POST",
        url,
        "Content-Type: application/json\r\n",
        5000,
        postData,
        resultData,
        resultHeaders
    );
    
    if (response == -1) {
        Print("HTTP Error: ", GetLastError());
    } else {
        string response = CharArrayToString(resultData);
        Print("Server Response: ", response);
    }
}

//+------------------------------------------------------------------+
//| Send Open Orders' information                                    |
//+------------------------------------------------------------------+
void sendOrdersData() {
    string ordersJson = "[";
    
    // Process active orders
    int totalOrders = OrdersTotal(); 
    for (int i = 0; i < totalOrders; i++) {
        if (OrderGetTicket(i)) {
            if (ordersJson != "[") {
                ordersJson += ",";
            }
            ordersJson += orderDetailsToJson();
        }
    }

    ordersJson += "]";
    
    string backendURL = backendBaseURL + sendOrdersDataEndpoint;
    sendToBackend(backendURL, ordersJson);
}

string orderDetailsToJson() {
    return StringFormat(
        "{"
        "\"login\":%I64d,"
        "\"ticket\":%I64d,"
        "\"symbol\":\"%s\","
        "\"comment\":\"%s\","
        "\"external_id\":\"%s\","
        "\"time_setup\":%d,"
        "\"type\":\"%s\","
        "\"state\":\"%s\","
        "\"time_expiration\":%d,"
        "\"time_done\":%d,"
        "\"time_setup_msc\":%I64d,"
        "\"time_done_msc\":%I64d,"
        "\"type_filling\":\"%s\","
        "\"type_time\":\"%s\","
        "\"magic\":%I64d,"
        "\"reason\":\"%s\","
        "\"position_id\":%I64d,"
        "\"position_by_id\":%I64d,"
        "\"volume_initial\":%.2f,"
        "\"volume_current\":%.2f,"
        "\"price_open\":%.5f,"
        "\"price_current\":%.5f,"
        "\"price_stoplimit\":%.5f,"
        "\"sl\":%.5f,"
        "\"tp\":%.5f"
        "}",
        AccountInfoInteger(ACCOUNT_LOGIN),
        OrderGetInteger(ORDER_TICKET),
        OrderGetString(ORDER_SYMBOL),
        OrderGetString(ORDER_COMMENT),
        OrderGetString(ORDER_EXTERNAL_ID),
        (datetime)OrderGetInteger(ORDER_TIME_SETUP),
        orderTypeToString((int)OrderGetInteger(ORDER_TYPE)),
        orderStateToString((int)OrderGetInteger(ORDER_STATE)),
        (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION),
        (datetime)OrderGetInteger(ORDER_TIME_DONE),
        OrderGetInteger(ORDER_TIME_SETUP_MSC),
        OrderGetInteger(ORDER_TIME_DONE_MSC),
        orderFillingTypeToString((int)OrderGetInteger(ORDER_TYPE_FILLING)),
        orderTypeTimeToString((int)OrderGetInteger(ORDER_TYPE_TIME)),
        OrderGetInteger(ORDER_MAGIC),
        orderReasonToString((int)OrderGetInteger(ORDER_REASON)),
        OrderGetInteger(ORDER_POSITION_ID),
        OrderGetInteger(ORDER_POSITION_BY_ID),
        OrderGetDouble(ORDER_VOLUME_INITIAL),
        OrderGetDouble(ORDER_VOLUME_CURRENT),
        OrderGetDouble(ORDER_PRICE_OPEN),
        OrderGetDouble(ORDER_PRICE_CURRENT),
        OrderGetDouble(ORDER_PRICE_STOPLIMIT),
        OrderGetDouble(ORDER_SL),
        OrderGetDouble(ORDER_TP)
    );
}

string orderTypeToString(int orderType) {
    switch(orderType) {
        case ORDER_TYPE_BUY:               return "ORDER_TYPE_BUY";
        case ORDER_TYPE_SELL:              return "ORDER_TYPE_SELL";
        case ORDER_TYPE_BUY_LIMIT:         return "ORDER_TYPE_BUY_LIMIT";
        case ORDER_TYPE_SELL_LIMIT:        return "ORDER_TYPE_SELL_LIMIT";
        case ORDER_TYPE_BUY_STOP:          return "ORDER_TYPE_BUY_STOP";
        case ORDER_TYPE_SELL_STOP:         return "ORDER_TYPE_SELL_STOP";
        case ORDER_TYPE_BUY_STOP_LIMIT:    return "ORDER_TYPE_BUY_STOP_LIMIT";
        case ORDER_TYPE_SELL_STOP_LIMIT:   return "ORDER_TYPE_SELL_STOP_LIMIT";
        case ORDER_TYPE_CLOSE_BY:          return "ORDER_TYPE_CLOSE_BY";
        default:                           return "UNKNOWN";
    }
}

string orderStateToString(int state) {
    switch (state) {
        case ORDER_STATE_STARTED:         return "ORDER_STATE_STARTED";
        case ORDER_STATE_PLACED:          return "ORDER_STATE_PLACED";
        case ORDER_STATE_CANCELED:        return "ORDER_STATE_CANCELED";
        case ORDER_STATE_PARTIAL:         return "ORDER_STATE_PARTIAL";
        case ORDER_STATE_FILLED:          return "ORDER_STATE_FILLED";
        case ORDER_STATE_REJECTED:        return "ORDER_STATE_REJECTED";
        case ORDER_STATE_EXPIRED:         return "ORDER_STATE_EXPIRED";
        case ORDER_STATE_REQUEST_ADD:     return "ORDER_STATE_REQUEST_ADD";
        case ORDER_STATE_REQUEST_MODIFY:  return "ORDER_STATE_REQUEST_MODIFY";
        case ORDER_STATE_REQUEST_CANCEL:  return "ORDER_STATE_REQUEST_CANCEL";
        default:                          return "UNKNOWN";
    }
}

string orderFillingTypeToString(int fillingType) {
    switch(fillingType) {
        case ORDER_FILLING_FOK:   return "ORDER_FILLING_FOK";    // Fill or Kill
        case ORDER_FILLING_IOC:   return "ORDER_FILLING_IOC";    // Immediate or Cancel
        case ORDER_FILLING_BOC:   return "ORDER_FILLING_BOC";    // Book or Cancel (Passive)
        case ORDER_FILLING_RETURN:return "ORDER_FILLING_RETURN"; // Return
        default:                  return "UNKNOWN";
    }
}

string orderTypeTimeToString(int typeTime) {
    switch(typeTime) {
        case ORDER_TIME_GTC:            return "ORDER_TIME_GTC";            // Good till cancel
        case ORDER_TIME_DAY:            return "ORDER_TIME_DAY";            // Good till trade day
        case ORDER_TIME_SPECIFIED:      return "ORDER_TIME_SPECIFIED";      // Good till expired
        case ORDER_TIME_SPECIFIED_DAY:  return "ORDER_TIME_SPECIFIED_DAY";  // Good till specific day
        default:                        return "UNKNOWN";
    }
}

string orderReasonToString(int reason) {
    switch(reason) {
        case ORDER_REASON_CLIENT: return "ORDER_REASON_CLIENT";  // Desktop terminal
        case ORDER_REASON_MOBILE: return "ORDER_REASON_MOBILE";  // Mobile app
        case ORDER_REASON_WEB:    return "ORDER_REASON_WEB";     // Web platform
        case ORDER_REASON_EXPERT: return "ORDER_REASON_EXPERT";  // MQL5 EA or script
        case ORDER_REASON_SL:     return "ORDER_REASON_SL";      // Stop Loss
        case ORDER_REASON_TP:     return "ORDER_REASON_TP";      // Take Profit
        case ORDER_REASON_SO:     return "ORDER_REASON_SO";      // Stop Out
        default:                  return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Send positions' information                                    |
//+------------------------------------------------------------------+
void sendPositionsData() {
    string positionsJson = "[";
    
    int totalPositions = PositionsTotal();
    for (int i = 0; i < totalPositions; i++) {
        if (PositionGetTicket(i)) {
            if (positionsJson != "[") {
                positionsJson += ",";
            }
            positionsJson += positionDetailsToJson();
        }
    }
    
    positionsJson += "]";
    
    string backendURL = backendBaseURL + sendPositionsDataEndpoint;
    sendToBackend(backendURL, positionsJson);
}


string positionDetailsToJson() {
    return StringFormat(
        "{"
        "\"login\":%I64d,"
        "\"ticket\":%I64d,"
        "\"time\":%d,"
        "\"time_msc\":%I64d,"
        "\"time_update\":%d,"
        "\"time_update_msc\":%I64d,"
        "\"type\":\"%s\","
        "\"magic\":%I64d,"
        "\"identifier\":%I64d,"
        "\"reason\":\"%s\","
        "\"volume\":%.2f,"
        "\"price_open\":%.5f,"
        "\"sl\":%.5f,"
        "\"tp\":%.5f,"
        "\"price_current\":%.5f,"
        "\"swap\":%.2f,"
        "\"profit\":%.2f,"
        "\"symbol\":\"%s\","
        "\"comment\":\"%s\","
        "\"external_id\":\"%s\""
        "}",
        AccountInfoInteger(ACCOUNT_LOGIN),
        PositionGetInteger(POSITION_TICKET),
        (datetime)PositionGetInteger(POSITION_TIME),
        PositionGetInteger(POSITION_TIME_MSC),
        (datetime)PositionGetInteger(POSITION_TIME_UPDATE),
        PositionGetInteger(POSITION_TIME_UPDATE_MSC),
        positionTypeToString((int)PositionGetInteger(POSITION_TYPE)),
        PositionGetInteger(POSITION_MAGIC),
        PositionGetInteger(POSITION_IDENTIFIER),
        positionReasonToString((int)PositionGetInteger(POSITION_REASON)),
        PositionGetDouble(POSITION_VOLUME),
        PositionGetDouble(POSITION_PRICE_OPEN),
        PositionGetDouble(POSITION_SL),
        PositionGetDouble(POSITION_TP),
        PositionGetDouble(POSITION_PRICE_CURRENT),
        PositionGetDouble(POSITION_SWAP),
        PositionGetDouble(POSITION_PROFIT),
        PositionGetString(POSITION_SYMBOL),
        PositionGetString(POSITION_COMMENT),
        PositionGetString(POSITION_EXTERNAL_ID)
    );
}

string positionTypeToString(int type) {
    switch (type) {
        case POSITION_TYPE_BUY: return "BUY";
        case POSITION_TYPE_SELL: return "SELL";
        default: return "UNKNOWN";
    }
}

string positionReasonToString(int reason) {
    switch (reason) {
        case POSITION_REASON_CLIENT: return "CLIENT";
        case POSITION_REASON_MOBILE: return "MOBILE";
        case POSITION_REASON_WEB: return "WEB";
        case POSITION_REASON_EXPERT: return "EXPERT";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Send Close Orders' (Deals') information                          |
//+------------------------------------------------------------------+
void sendDealsData() {
    datetime end = TimeCurrent();
    datetime start = end - (dealsUpdateInterval + dealsUpdateBuffer);
    HistorySelect(start, end);
    
    string backendURL = backendBaseURL + sendDealsDataEndpoint;
    string ordersJson = "[";
    bool hasDeals = false;
    
    uint totalDeals = HistoryDealsTotal();
    if (totalDeals == 0) {
        Print("ℹ️ No deals to process.");
        sendToBackend(backendURL, "[]");
        return;
    } else {
        Print("🔍 Total deals found in history: ", totalDeals);
    }
    
    ulong ticket = 0;
    for (uint i = 0; i < totalDeals; i++) {
        // Try to get deals ticket
        if((ticket = HistoryDealGetTicket(i)) > 0) {
            Print("Ticket num: ", ticket);
        }
        
        if (hasDeals) {
            ordersJson += ",";
        }

        ordersJson += dealToJson(ticket);
        hasDeals = true; 
    }
    
    ordersJson += "]";
    
    sendToBackend(backendURL, ordersJson);
}

string dealToJson(ulong ticket) {
    return StringFormat(
        "{"
        "\"login\":%I64d,"
        "\"ticket\":%I64d,"
        "\"order\":%I64d,"
        "\"time\":%d,"
        "\"time_msc\":%I64d,"
        "\"type\":\"%s\","
        "\"entry\":\"%s\","
        "\"magic\":%I64d,"
        "\"reason\":\"%s\","
        "\"position_id\":%I64d,"
        "\"volume\":%.2f,"
        "\"price\":%.5f,"
        "\"commission\":%.2f,"
        "\"swap\":%.2f,"
        "\"profit\":%.2f,"
        "\"fee\":%.2f,"
        "\"sl\":%.5f,"
        "\"tp\":%.5f,"
        "\"symbol\":\"%s\","
        "\"comment\":\"%s\","
        "\"external_id\":\"%s\""
        "}",
        AccountInfoInteger(ACCOUNT_LOGIN),
        HistoryDealGetInteger(ticket, DEAL_TICKET),
        HistoryDealGetInteger(ticket, DEAL_ORDER),
        (datetime)HistoryDealGetInteger(ticket, DEAL_TIME),
        HistoryDealGetInteger(ticket, DEAL_TIME_MSC),
        dealTypeToString((int)HistoryDealGetInteger(ticket, DEAL_TYPE)),
        dealEntryToString((int)HistoryDealGetInteger(ticket, DEAL_ENTRY)),
        HistoryDealGetInteger(ticket, DEAL_MAGIC),
        dealReasonToString((int)HistoryDealGetInteger(ticket, DEAL_REASON)),
        HistoryDealGetInteger(ticket, DEAL_POSITION_ID),
        HistoryDealGetDouble(ticket, DEAL_VOLUME),
        HistoryDealGetDouble(ticket, DEAL_PRICE),
        HistoryDealGetDouble(ticket, DEAL_COMMISSION),
        HistoryDealGetDouble(ticket, DEAL_SWAP),
        HistoryDealGetDouble(ticket, DEAL_PROFIT),
        HistoryDealGetDouble(ticket, DEAL_FEE),
        HistoryDealGetDouble(ticket, DEAL_SL),
        HistoryDealGetDouble(ticket, DEAL_TP),
        HistoryDealGetString(ticket, DEAL_SYMBOL),
        HistoryDealGetString(ticket, DEAL_COMMENT),
        HistoryDealGetString(ticket, DEAL_EXTERNAL_ID)
    );
}

string dealTypeToString(int type) {
    switch (type) {
        case DEAL_TYPE_BUY: return "BUY";
        case DEAL_TYPE_SELL: return "SELL";
        case DEAL_TYPE_BALANCE: return "BALANCE";
        case DEAL_TYPE_CREDIT: return "CREDIT";
        case DEAL_TYPE_CHARGE: return "CHARGE";
        case DEAL_TYPE_CORRECTION: return "CORRECTION";
        case DEAL_TYPE_BONUS: return "BONUS";
        case DEAL_TYPE_COMMISSION: return "COMMISSION";
        case DEAL_TYPE_COMMISSION_DAILY: return "COMMISSION_DAILY";
        case DEAL_TYPE_COMMISSION_MONTHLY: return "COMMISSION_MONTHLY";
        case DEAL_TYPE_COMMISSION_AGENT_DAILY: return "AGENT_COMMISSION_DAILY";
        case DEAL_TYPE_COMMISSION_AGENT_MONTHLY: return "AGENT_COMMISSION_MONTHLY";
        case DEAL_TYPE_INTEREST: return "INTEREST";
        case DEAL_TYPE_BUY_CANCELED: return "BUY_CANCELED";
        case DEAL_TYPE_SELL_CANCELED: return "SELL_CANCELED";
        case DEAL_DIVIDEND: return "DIVIDEND";
        case DEAL_DIVIDEND_FRANKED: return "DIVIDEND_FRANKED";
        case DEAL_TAX: return "TAX";
        default: return "UNKNOWN";
    }
}

string dealEntryToString(int entry) {
    switch (entry) {
        case DEAL_ENTRY_IN: return "IN";
        case DEAL_ENTRY_OUT: return "OUT";
        case DEAL_ENTRY_INOUT: return "REVERSE";
        case DEAL_ENTRY_OUT_BY: return "OUT_BY";
        default: return "UNKNOWN";
    }
}

string dealReasonToString(int reason) {
    switch (reason) {
        case DEAL_REASON_CLIENT: return "CLIENT";
        case DEAL_REASON_MOBILE: return "MOBILE";
        case DEAL_REASON_WEB: return "WEB";
        case DEAL_REASON_EXPERT: return "EXPERT";
        case DEAL_REASON_SL: return "SL";
        case DEAL_REASON_TP: return "TP";
        case DEAL_REASON_SO: return "SO";
        case DEAL_REASON_ROLLOVER: return "ROLLOVER";
        case DEAL_REASON_VMARGIN: return "VMARGIN";
        case DEAL_REASON_SPLIT: return "SPLIT";
        case DEAL_REASON_CORPORATE_ACTION: return "CORPORATE_ACTION";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Send account's information                                       |
//+------------------------------------------------------------------+
void sendAccountData() {
    string accountJson = "[" + accountDetailsToJson() + "]";
    
    string backendURL = backendBaseURL + sendAccountDataEndpoint;
    sendToBackend(backendURL, accountJson);
} 

string accountDetailsToJson() {
    return StringFormat(
        "{"
        "\"login\":%I64d,"
        "\"trade_mode\":\"%s\","
        "\"leverage\":%d,"
        "\"limit_orders\":%d,"
        "\"margin_so_mode\":\"%s\","
        "\"trade_allowed\":%s,"
        "\"trade_expert\":%s,"
        "\"margin_mode\":\"%s\","
        "\"currency_digits\":%d,"
        "\"fifo_close\":%s,"
        "\"hedge_allowed\":%s,"
        "\"balance\":%.2f,"
        "\"credit\":%.2f,"
        "\"profit\":%.2f,"
        "\"equity\":%.2f,"
        "\"margin\":%.2f,"
        "\"margin_free\":%.2f,"
        "\"margin_level\":%.2f,"
        "\"margin_so_call\":%.2f,"
        "\"margin_so_so\":%.2f,"
        "\"margin_initial\":%.2f,"
        "\"margin_maintenance\":%.2f,"
        "\"assets\":%.2f,"
        "\"liabilities\":%.2f,"
        "\"commission_blocked\":%.2f,"
        "\"name\":\"%s\","
        "\"server\":\"%s\","
        "\"currency\":\"%s\","
        "\"company\":\"%s\""
        "}",
        AccountInfoInteger(ACCOUNT_LOGIN),
        accountTradeModeToString((int)AccountInfoInteger(ACCOUNT_TRADE_MODE)),
        AccountInfoInteger(ACCOUNT_LEVERAGE),
        AccountInfoInteger(ACCOUNT_LIMIT_ORDERS),
        accountStopoutModeToString((int)AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE)),
        AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "true" : "false",
        AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "true" : "false",
        accountMarginModeToString((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)),
        AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS),
        AccountInfoInteger(ACCOUNT_FIFO_CLOSE) ? "true" : "false",
        AccountInfoInteger(ACCOUNT_HEDGE_ALLOWED) ? "true" : "false",
        AccountInfoDouble(ACCOUNT_BALANCE),
        AccountInfoDouble(ACCOUNT_CREDIT),
        AccountInfoDouble(ACCOUNT_PROFIT),
        AccountInfoDouble(ACCOUNT_EQUITY),
        AccountInfoDouble(ACCOUNT_MARGIN),
        AccountInfoDouble(ACCOUNT_MARGIN_FREE),
        AccountInfoDouble(ACCOUNT_MARGIN_LEVEL),
        AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL),
        AccountInfoDouble(ACCOUNT_MARGIN_SO_SO),
        AccountInfoDouble(ACCOUNT_MARGIN_INITIAL),
        AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE),
        AccountInfoDouble(ACCOUNT_ASSETS),
        AccountInfoDouble(ACCOUNT_LIABILITIES),
        AccountInfoDouble(ACCOUNT_COMMISSION_BLOCKED),
        AccountInfoString(ACCOUNT_NAME),
        AccountInfoString(ACCOUNT_SERVER),
        AccountInfoString(ACCOUNT_CURRENCY),
        AccountInfoString(ACCOUNT_COMPANY)
    );
}

string accountTradeModeToString(int mode) {
    switch(mode) {
        case ACCOUNT_TRADE_MODE_DEMO:    return "demo";
        case ACCOUNT_TRADE_MODE_CONTEST: return "contest";
        case ACCOUNT_TRADE_MODE_REAL:    return "real";
        default:                         return "unknown";
    }
}

string accountStopoutModeToString(int mode) {
    switch(mode) {
        case ACCOUNT_STOPOUT_MODE_PERCENT: return "percent";
        case ACCOUNT_STOPOUT_MODE_MONEY:   return "money";
        default:                           return "unknown";
    }
}

string accountMarginModeToString(int mode) {
    switch(mode) {
        case ACCOUNT_MARGIN_MODE_RETAIL_NETTING:  return "retail_netting";
        case ACCOUNT_MARGIN_MODE_EXCHANGE:        return "exchange";
        case ACCOUNT_MARGIN_MODE_RETAIL_HEDGING:  return "retail_hedging";
        default:                                   return "unknown";
    }
}
