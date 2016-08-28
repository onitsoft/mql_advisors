//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2012, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

input bool is_tester=true;
input int check_bars_range=5;
input double margin_consumption=0.25;
input double decrease_coeff_init=0.02;
input double lot_margin=1000;
input double robot_amount_deposit_percent=0.25;

input int max_intercept_steps=10;
input bool intercept_mode = true;
input double intercept_lot=1;
input double quote_lot=1;
input double max_vol=10;
input double intercept_percent_range=0.01;
input double grid_percent_range=0.01;
input int grid_chain_sec=7000;
input double unliquid_mode=false;
input bool recover_expired_daily_ordes=true;
input double critical_margin_level=10000;

bool quote_mode= false;
int quote_step = 2;

bool pos_timing_control=false;
double curr_last=0;
double curr_bid = 0;
double curr_ask = 0;
MqlTick last_tick;
int curr_position=0;
double curr_deposit=0;

bool low_margin=false;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct print_info
  {
   double            price;
   ulong             volume;
   double            buy_true;
   int               last_print_index;
   long              time_msc;
  };

print_info print_registry[300];

print_info curr_print;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct accumulate_info
  {
   double            price_open;
   bool              ask_true;// ask true = sell limit
   double            volume;
   datetime          time;
   int               expiration_sec;
   int               pos_expiration_sec;
   int               is_executed;
   int               is_covered;
   ulong             ticket_open;
   int               boost_flag;           //boost flag = intercept
   int               spread_boost_flag;
   double            index_value;
   double            result_dev_value;
   datetime          execution_time;
   int               pos_expiration_ticket;
   double            pos_expirate_range;
   int               expiration_range_ticket;
   int               lead_flag;
   double            execution_strike_price;
   int               expiration_chain_sec;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
accumulate_info accumulate_registry[300];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct bars_parameters
  {
   double            small_bars_size;
   double            middle_bars_size;
   double            large_bars_size;
   double            bars_recovery_factor;

   double            small_ticks_size;
   double            middle_ticks_size;
   double            large_ticks_size;

   double            ticks_recovery_factor;
   double            ticks_momentum_range;

   double            small_bars_percentile;
   double            middle_bars_percentile;
   double            large_bars_percentile;

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct pos_info

  {
   double            price_open;
   double            sl_price;
   double            tp_price;
   double            volume;
   datetime          time;

   int               is_actual_trade;

   int               expiration_sec;
   double            price_call;

   double            first_accumulation_price;
   double            last_accumulation_price;
   double            last_accumulation_volume;
   double            price_import_value;
   ulong             ticket_open;
   ulong             ticket_tp;
   ulong             ticket_sl;
   int               is_tp_placed;
   int               direction;

   double            price_level_1;
   double            price_level_2;
   double            price_level_3;

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct book_info
  {
   int               fill_flag;
   double            small_book_volume;
   double            middle_book_volume;
   double            large_book_volume;

   double            small_10_volume;
   double            middle_10_volume;
   double            large_10_volume;
   int               book_size;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct accumulate_vol_info
  {
   double            first_acc_price_bid;
   double            last_acc_price_bid;
   double            acc_volume_bid;

   double            average_volume_by_range;

   double            first_acc_price_ask;
   double            last_acc_price_ask;
   double            acc_volume_ask;

  };

pos_info info_pos_bid;
pos_info info_pos_ask;
pos_info info_pos_bid_sub1;
pos_info info_pos_bid_sub2;
pos_info info_pos_ask_sub1;
pos_info info_pos_ask_sub2;
bars_parameters bars_info;

book_info curr_book_param;
int book_param_count=1;
int expiration_pos_ticket_count=1;

double index_decrease_coeff=0;
int expirate_range_ticket_count=1;

double last_accumulate_buy_volume_executed=0;
double last_accumulate_sell_volume_executed=0;

double last_accumulate_buy_volume_pending=0;
double last_accumulate_sell_volume_pending=0;

double lowest_buy_price_executed=0;
double lowest_sell_price_executed=0;

double highest_sell_price_executed=0;
double highest_buy_price_executed=0;

double extremum_index=0;
double extremum_result_dev=0;

double nearest_buy_pending=0;
double nearest_sell_pending=0;

double nearest_buy_executed=0;
double nearest_sell_executed=0;
//| Expert initialization function                                   |
double nearest_executed_buy_result_dev=0;
double nearest_executed_sell_result_dev=0;
double nearest_pending_buy_res_dev=0;
double nearest_pending_sell_res_dev=0;
double last_boost_trade=0;
double pending_buy_lot_total=0;
double pending_sell_lot_total=0;

double lot_parts_exec_buy=0;
double lot_parts_exec_sell=0;

double nearest_boost_price_pending=0;
double nearest_boost_executed=0;
double extremum_boost_price=0;

bool near_buy_pending_flag_simple= false;
bool near_buy_pending_flag_boost = false;

bool near_sell_pending_flag_simple= false;
bool near_sell_pending_flag_boost = false;

double spread_executed_lot=0;
double spread_underwater_executed_lot=0;

book_info book_registry[100];

book_info curr_book;// resultiruushie parametri

int fl=0;
//+------------------------------------------------------------------+
//|        Account login, validate deposit                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   curr_deposit=GlobalVariableGet("curr_depo");
   MarketBookAdd(_Symbol);
   EventSetTimer(2);

   if(curr_deposit==0)
     {
      curr_deposit=1000000;
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+----------------------------------------------------------------------+
//|        Tick event, everytime the price changes this funtion is called|
//+----------------------------------------------------------------------+
void OnTick()
  {
   MqlDateTime stime;
   TimeToStruct(TimeCurrent(),stime);
   SymbolInfoTick(_Symbol,last_tick);
   if(stime.hour==10 && stime.min==0 && stime.sec<5)
     {
      return;
     }
//currenty always true
   if(intercept_mode)
     {
      MqlRates mrate[];
      CopyRates(_Symbol,PERIOD_H1,0,check_bars_range,mrate);
      int fl_init=0;
      int fl_percent=0;
      int fl_impact = 0;
      int fl_margin = 0;
      // @var double pending_buy_lot_total amount of pending buy orders, in case of pending orders cease execution
      if(pending_buy_lot_total==0)
        {fl_init=1;}

      // Measure that the price change is acceptable according to our strategy @see README
      if((mrate[0].close-last_tick.bid)/mrate[0].close>decrease_coeff_init)
        {fl_percent=1;}

      if(IsNotNewHighImpact(_Symbol,check_bars_range,3,mrate[0].close,last_tick.bid))
        {fl_impact=1;}

      if(lowest_buy_price_executed!=0 && (lowest_buy_price_executed-last_tick.bid)/lowest_buy_price_executed>grid_percent_range)
        {fl_percent=1;}

      ArraySetAsSeries(mrate,true);
      // if the decrease occurs on the opening, disregard percent filter @see fl_percent
      if(stime.hour==10)
        {
         //Check again if the decrease is high enough to enter a new position
         if((mrate[0].open-last_tick.bid)/mrate[0].open>decrease_coeff_init)
           {fl_percent=1;fl_impact=1;}

        }
      //check if position already exists on this asset, internal function
      if(PositionSelect(_Symbol))
        {
         double total_lot=PositionGetDouble(POSITION_VOLUME)+pending_buy_lot_total;
         //check if current used capital is not higher than allocated amount from the deposit to be used by the robot
         if(total_lot*lot_margin<curr_deposit*robot_amount_deposit_percent)
           {fl_margin=1;}
        }
      else if(pending_buy_lot_total*lot_margin<curr_deposit*robot_amount_deposit_percent)
        {fl_margin=1;}

      //check that all filters pass
      if(fl_init==1 && fl_impact==1 && fl_percent==1 && fl_margin==1)
        {
         //buys lot amount for every decrease of grid_percnet_ragne in price
         CreateStockGrid(last_tick.bid,intercept_lot,grid_percent_range,grid_percent_range,false,0,grid_chain_sec);
         GetAccumulateAverageParameteres(curr_last,false);
        }
     }
//might not be used
   if(PositionSelect(_Symbol))
     {
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         //BUY
         curr_position=6;

        }
      else
        {
         //SELL
         curr_position=5;
        }
      accumulate_registry[100].price_open=1111;
     }
   else
     {
      curr_position=0;
     }
    if (is_tester) {
       executeTestOrders();
    }
  }
//checks if the tick is not a proceeded by a high spike (e.g don't but on a correction)
bool IsNotNewHighImpact(string symbol,int range,double  check_movement_coeff,double price_init,double curr_price)
  {
   double max=0;
   MqlRates rates[];
   CopyRates(symbol,_Period,0,range,rates);
   for(int i=0;i<range;i++)
     {
      if(max==0){max=rates[i].high;}
      if(rates[i].high>max){max=rates[i].high;}
     }
   if(max-price_init==0){return false;}
   if((price_init-curr_price)/(max-price_init)<check_movement_coeff)
     {return false;}
   return true;
  }
//+------------------------------------------------------------------+
//| Place new buy order                                              |
//+------------------------------------------------------------------+
void PlaceOrder(const double price,const double lots,const bool buy_true,const bool limit_true,const ulong magic)
  {
   MqlTradeRequest mrequest;
   MqlTradeResult mresult;
   mrequest.action=TRADE_ACTION_PENDING;
   mrequest.symbol = _Symbol;
   mrequest.volume = lots;
   mrequest.price=price;
//  mrequest.stoplimit=last_tick.bid;
   mrequest.sl = 0;
   mrequest.tp = 0;
   mrequest.magic=magic;
   if(limit_true==true)
     {
      if(buy_true==true)
        {mrequest.type=ORDER_TYPE_BUY_LIMIT;}
      else
        {mrequest.type=ORDER_TYPE_SELL_LIMIT;}
     }
   else
     {
      if(buy_true==true)
        {mrequest.type=ORDER_TYPE_BUY_STOP;}
      else
        {mrequest.type=ORDER_TYPE_SELL_STOP;}
     }
   mrequest.type_filling=ORDER_FILLING_RETURN;
   mrequest.type_time=ORDER_TIME_DAY;
   mrequest.expiration=0;
//  mrequest.expiration=TimeToDayTime((datetime)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_TIME));
   OrderSendAsync(mrequest,mresult);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                       @todo add trade lib                        |
//+------------------------------------------------------------------+
void OrderDeleteAsync(ulong ticket)
  {
//sync
   trade.OrderDelete(ticket);
   return;
//asynce
   MqlTradeRequest m_request;
   MqlTradeResult m_result;
   m_request.action=TRADE_ACTION_REMOVE;
   m_request.order=ticket;
   OrderSendAsync(m_request,m_result);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.order_state==ORDER_STATE_FILLED)
     {
      if(trans.order_type==ORDER_TYPE_BUY_LIMIT)///////BUY LIMIT
        {
         if(trans.price==info_pos_bid.price_open && info_pos_bid.is_tp_placed==0)
           {
            info_pos_bid.ticket_open=0;
            info_pos_bid.is_tp_placed=1;

           }
         ///////////////////////////////////////////////////////////Accumulate registry
         if(trans.volume!=0)
            // Caching mechanism, easy to access BUY and SELL data
           {SetExecutionToRegistryOrder(trans.price,false,trans.volume);}

        }
      ///// END BUY LIMIT
      else if(trans.order_type==ORDER_TYPE_SELL_LIMIT)///////SELL LIMIT
        {
         if(trans.price==info_pos_ask.price_open && info_pos_ask.is_tp_placed==0)
           {
            info_pos_ask.ticket_open=0;
            info_pos_ask.is_tp_placed=1;
            //PlaceOrder(info_pos_ask.sl_price,info_pos_ask.volume,true,false,0);
            //PlaceOrder(info_pos_ask.tp_price,info_pos_ask.volume,true,true,0); 

            //v dannom slu4ae suda pishem zna4enie indeksa
           }
         ///////////////////////////////////////////////////////////Accumulate registry
         if(trans.volume!=0)
           {
            SetExecutionToRegistryOrder(trans.price,true,trans.volume);
           }

        }//END SELL LIMIT

      ///////////////////////////////////////COUNTER MODULE

      /////////////////////////////////////////

     }

///////////////////////////////////ticket module
   if(trans.order_state==ORDER_STATE_PLACED)
     {
      if(trans.order_type==ORDER_TYPE_BUY_LIMIT)
        {
         //only this line is relevant
         AddTicketToRegistry(trans.order,trans.price,false);
        }
      else if(trans.order_type==ORDER_TYPE_SELL_LIMIT)
        {
         if(trans.price==info_pos_ask.price_open) {                     info_pos_ask.ticket_open=trans.order;        Print("OnTradeTransaction:Set ask open ticket ",trans.order);}//logs
         if(trans.price==info_pos_bid.tp_price) {                       info_pos_bid.ticket_tp=trans.order;          Print("OnTradeTransaction:Set bid_tp ticket ",trans.order);}//logs
         if(trans.price==info_pos_ask_sub1.price_open){                 info_pos_ask_sub1.ticket_open=trans.order;   Print("OnTradeTransaction:Set ask_sub1 open ticket ",trans.order);}//logs
         if(trans.price==info_pos_ask_sub2.price_open){                 info_pos_ask_sub2.ticket_open=trans.order;   Print("OnTradeTransaction:Set ask_sub2 open ticket ",trans.order);}//logs
         AddTicketToRegistry(trans.order,trans.price,true);
        }

     }
/////////////////////////////////////////
//for higher volumes
//////////////////////////////////////////PARTIAL MODULE

   if(trans.order_state==ORDER_STATE_PARTIAL)
     {
      if(trans.order_type==ORDER_TYPE_BUY_LIMIT)//BUY LIMIT
        {

        }
      else//SELL LIMIT
        {

        }
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|  Remove unexectured orders which weren't executred in a certain time, REDUNDANT                                            |
//+------------------------------------------------------------------+

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////counter check;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                       Calculate how much return to expect in percents for the position, take profit, limit for buy                                           |
//+------------------------------------------------------------------+
double GetTargetPercentPrice(double price,double percentage,bool higher)//procenti ukazivautsya v izmenenii
  {
   double prom_price=0;
   if(higher)
     {
      prom_price=price+(price*percentage);
      double curr_point=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(curr_point!=0.0001 && curr_point!=0.001 && curr_point!=0.01 && curr_point!=0.1 && curr_point!=1 && curr_point!=10)
        {
         prom_price=NormalizeDouble(prom_price,_Digits-1);
        }
      else
        {
         prom_price=NormalizeDouble(prom_price,_Digits);
        }

     }
   else
     {
      prom_price=price-(price*percentage);
      double curr_point=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(curr_point!=0.0001 && curr_point!=0.001 && curr_point!=0.01 && curr_point!=0.1 && curr_point!=1 && curr_point!=10)
        {prom_price=NormalizeDouble(prom_price,_Digits-1);}
      else
        {prom_price=NormalizeDouble(prom_price,_Digits);}

     }
   return prom_price;

  }
//+------------------------------------------------------------------+
//|                for future imlementation                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void SetNullBookStructure()
  {
   int size=ArraySize(book_registry);
   for(int i=0;i<size;i++)
     {
      book_registry[i].fill_flag=0;
      book_registry[i].large_10_volume=0;
      book_registry[i].large_book_volume=0;
      book_registry[i].middle_10_volume=0;
      book_registry[i].middle_book_volume=0;
      book_registry[i].small_10_volume=0;
      book_registry[i].small_book_volume=0;
     }

  }
//+------------------------------------------------------------------+
//|        calculate average market depth                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void GetBookParameters(double percent_of_top,bool average_research_flag=true)
  {
   MqlBookInfo book[];
   MarketBookGet(_Symbol,book);
   int bookSize=ArraySize(book);
   curr_book.book_size=bookSize;
   if(average_research_flag)
     {
      int count=0;
      long cum_vol=0;

      int count_small = 0;
      int count_middle=0;
      int count_large =0;

      double small=0;
      double middle= 0;
      double large = 0;
      long range_vol[];
      ArrayResize(range_vol,bookSize);

      for(int i=0;i<bookSize;i++)
        {
         if(book[i].volume!=0)
           {
            range_vol[count]=book[i].volume;
            count++;
           }
        }
      ArraySort(range_vol);
      for(int i=1;i<count;i++)
        {
         if(i<count/3)
           {
            count_small++;
            small=small+range_vol[i];
           }
         else if(i>count/3 && i<count-(count/3))
           {
            count_middle++;
            middle=middle+range_vol[i];
           }
         else if(i>(count-(count/percent_of_top)))
           {
            count_large++;
            large=large+range_vol[i];
           }
        }
      curr_book_param.fill_flag=1;
      curr_book_param.small_book_volume=small;
      curr_book_param.middle_book_volume=middle;
      curr_book_param.large_book_volume=large;
      book_registry[book_param_count]=curr_book_param;
      if(book_param_count==99)
        {book_param_count=1;}else{book_param_count++;}
     }
  }
//+------------------------------------------------------------------+
//|                        create orders grid, add to local register using struct                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CreateStockGrid(double init_stock_price,double lot,double price_percent_step,double strike_percentile,bool ask_true,int exp_sec,int exp_chain_sec,bool book_mode=false,int book_step=1,int steps=3,bool intercept_flag=false,bool quote_flag=false,int counter_book_flag=0,double progressive_coeff=0)//1 step = init price;

  {
   double drop_modifier=1;
   double curr_pr=init_stock_price;
   if(ask_true)
     {
      if(!book_mode)
        {
         double adapted_percent_price=init_stock_price;
         for(int i=1;i<=steps;i++)
           {
            double st_price=GetTargetPercentPrice(adapted_percent_price,strike_percentile,false);
            
            AddOrderToRegistry(adapted_percent_price,lot,exp_sec,exp_chain_sec,st_price,true,intercept_flag,TimeCurrent());
            if(!is_tester) {
                 PlaceOrder(adapted_percent_price,lot,false,true,0);
            }
           
            adapted_percent_price=GetTargetPercentPrice(adapted_percent_price,price_percent_step,true);
            if(i>1 && progressive_coeff!=0)
              {drop_modifier=drop_modifier+progressive_coeff;}

            //ras4et point dobavit'
           }
        }
      else
        {
         MqlBookInfo mbook[];
         MarketBookGet(_Symbol,mbook);
         int size=ArraySize(mbook);

         for(int x=0;x<size;x++)
           {
            if(mbook[x].price==init_stock_price)
              {
               int count= 0;
               for(int i=x;i>=0;i--)
                 {
                  if(count<=steps)
                    {
                     double st_price=0;
                     if(counter_book_flag){st_price=mbook[i+1].price;}
                     else
                       {st_price=GetTargetPercentPrice(mbook[i].price,strike_percentile,false);}

                     AddOrderToRegistry(mbook[i].price,lot,exp_sec,exp_chain_sec,st_price,true,intercept_flag,TimeCurrent());
                     PlaceOrder(mbook[i].price,lot,false,true,0);
                     count++;
                    }
                 }
               break;
              }
           }
        }
     }
   else/////// Ask_true = false
     {
      if(!book_mode)
        {
         double adapted_percent_price=init_stock_price;
         for(int i=1;i<=steps;i++)
           {
            double st_price=GetTargetPercentPrice(adapted_percent_price,strike_percentile,true);
            AddOrderToRegistry(adapted_percent_price,lot,exp_sec,exp_chain_sec,st_price,false,intercept_flag,TimeCurrent());
            PlaceOrder(adapted_percent_price,lot,true,true,0);
            adapted_percent_price=GetTargetPercentPrice(adapted_percent_price,price_percent_step,false);

            //ras4et point dobavit'
           }
        }
      else
        {
         MqlBookInfo mbook[];
         MarketBookGet(_Symbol,mbook);
         int size=ArraySize(mbook);

         for(int x=0;x<size;x++)
           {
            if(mbook[x].price==init_stock_price)
              {
               int count = 0;
               for(int i = x;i<size;i++)
                 {
                  if(count<=steps)
                    {
                     double st_price=0;
                     if(counter_book_flag){st_price=mbook[i-1].price;}
                     else
                       {st_price=GetTargetPercentPrice(mbook[i].price,strike_percentile,true);}
                     AddOrderToRegistry(mbook[i].price,lot,exp_sec,exp_chain_sec,st_price,false,intercept_flag,TimeCurrent());
                     PlaceOrder(mbook[i].price,lot,true,true,0);
                     count++;
                    }
                  else{break;}
                 }
               break;
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|               to predict possible price change pe candle, not in use = predict volatility of asset                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void SetBarsSize(int range,int percent_of_top,bool tick_mode=false,int custom_set=0,int recovery_factor_range=1) //ustanavlivaet srednie razmeri barov po kategoriyam: naimenshie, srednie i naibloshie
  {
   if(!tick_mode)
     {
      double range_mass[];
      ArrayResize(range_mass,range,5);
      MqlRates rates[];
      CopyRates(_Symbol,_Period,0,range,rates);
      ArraySetAsSeries(rates,true);
      MqlDateTime stime;
      ArrayInitialize(range_mass,10000);
      int count= 0;
      for(int i=1;i<range;i++)
        {
         TimeToStruct(rates[i].time,stime);
         if(stime.hour==10 && stime.min==0)
           {break;}
         range_mass[count]=rates[i].high-rates[i].low;
         count++;
        }
      ArraySort(range_mass);

      //step 1
      double small=0;
      double middle= 0;
      double large = 0;

      int count_small=0;
      int count_middle= 0;
      int count_large = 0;
      for(int i=1;i<count;i++)
        {
         if(i<count/3)
           {
            count_small++;
            small=small+range_mass[i];
           }
         else if(i>count/3 && i<count-(count/3))
           {
            count_middle++;
            middle=middle+range_mass[i];
           }
         else if(i>(count-(count/percent_of_top)))
           {
            count_large++;
            large=large+range_mass[i];
           }
        }
      if(count_small!=0)
        {bars_info.small_bars_size=small/count_small;}
      if(count_middle!=0)
        {bars_info.middle_bars_size=middle/count_middle;}
      if(count_large!=0)
        {bars_info.large_bars_size=large/count_large;}

      if(last_tick.last!=0)
        {
         bars_info.small_bars_percentile=(bars_info.small_bars_size/last_tick.last)*100;
         bars_info.middle_bars_percentile=(bars_info.middle_bars_size/last_tick.last)*100;
         bars_info.large_bars_percentile=(bars_info.large_bars_size/last_tick.last)*100;
        }
     }
   else
     {

     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

// called from market depth calc fn, for future use
void GetResultBookParam()
  {
   long small=0;
   long middle= 0;
   long large = 0;
   int count=0;
   int size=ArraySize(book_registry);
   for(int i=0;i<100;i++)
     {
      if(book_registry[i].fill_flag==0){continue;}
      if(book_registry[i].small_book_volume!=0 && book_registry[i].middle_book_volume!=0 && book_registry[i].large_book_volume!=0)
        {
         small=small+book_registry[i].small_book_volume;
         middle= middle+book_registry[i].middle_book_volume;
         large = large+book_registry[i].large_book_volume;
         count++;
        }
     }
   curr_book.small_book_volume=small/count;
   curr_book.middle_book_volume=middle/count;
   curr_book.large_book_volume=large/count;

  }
//+------------------------------------------------------------------+
//|              average trade volume for a range of time                                                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
long GetAverageVolume(int range)
  {
   MqlRates rate[];
   CopyRates(_Symbol,_Period,1,range,rate);
   long c_vol=0;
   int c=0;
   for(int f=0;f<range;f++)

     {
      if(rate[f].real_volume==0){continue;}
      c_vol=c_vol+rate[f].real_volume;
      c++;
     }
   long result=c_vol/c;
   return result;
  }
//+------------------------------------------------------------------+
//|                     get large orders to try to perceed, future use                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
double GetActualAccumulation(int min_vol,bool ask_true,int def_average_vol,int def_cumulative_vol) //esle def_average vol = 0 togda ras4itivat srednii obiem na osnove min vol
  {
   double last_accumulation_price=0;
   double first_accumulation_price=0;
   int m_best_ask_index=0;
   int m_best_bid_index=0;
   MqlBookInfo MarketBook[];
   MarketBookGet(_Symbol,MarketBook);
//Find best ask by slow full search
   int fl_start= 0;
   int bookSize=ArraySize(MarketBook);
   for(int i=0; i<bookSize; i++)

     {
      if((MarketBook[i].type==BOOK_TYPE_BUY) || (MarketBook[i].type==BOOK_TYPE_BUY_MARKET))
        {
         m_best_ask_index=i-1;
         m_best_bid_index= i;
         break;
        }
     }

   if(MarketBook[m_best_ask_index].price==0 || MarketBook[m_best_ask_index].volume==0)
     {
      for(int i=m_best_ask_index;i>=0;i--)

        {
         if(MarketBook[i].price!=0)
           {
            m_best_ask_index=i;
            break;
           }
        }
     }
//////////////////////////////////////////////////////////////////////////////////////////
   double average_min_vol=0;

   if(def_average_vol==0)
     {
      if(ask_true)
        {
         long cum_vol=0;
         int count = 0;
         for(int i = m_best_ask_index;i>0;i--)
           {
            if(MarketBook[i].volume<min_vol)
              {cum_vol=cum_vol+MarketBook[i].volume;count++;}
           }
         if(count!=0)
           {average_min_vol=cum_vol/count;}
        }

      else
        {
         long cum_vol=0;
         int count=0;
         for(int i= m_best_bid_index;i<bookSize;i++)
           {
            if(MarketBook[i].volume<min_vol)
              {cum_vol=cum_vol+MarketBook[i].volume;count++;}
            if(count!=0)
              {average_min_vol=cum_vol/count;}
           }
        }
     }
   double curr_average_min;
   if(def_average_vol==0)
     {curr_average_min=average_min_vol;}
   else{curr_average_min=def_average_vol;}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   if(ask_true)
     {
      for(int i=m_best_ask_index;i>0;i--)

        {
         if(MarketBook[i].volume>curr_average_min*2 && fl_start==0)
           {
            first_accumulation_price=MarketBook[i].price;fl_start=1;
            int count=0;
            int const_count=0;
            long cumulative_vol=0;
            int big_vol_flag=0;
            long largest_vol=0;

            for(int a=i;a>0;a--)

              {
               count++;
               cumulative_vol=cumulative_vol+MarketBook[a].volume;
               if(MarketBook[a].volume>largest_vol){largest_vol=MarketBook[a].volume;}
               if(cumulative_vol>=def_cumulative_vol)
                 {last_accumulation_price=MarketBook[a].price;break;}
              }
           }
        }
     }

   else
     {
      for(int i=m_best_bid_index;i<bookSize;i++)

        {
         if(MarketBook[i].volume>curr_average_min*2 && fl_start==0)
           {
            first_accumulation_price=MarketBook[i].price; fl_start=1;
            int count=0;
            int const_count=0;
            int big_vol_flag= 0;
            long largest_vol=0;
            long cumulative_vol=0;
            for(int a=i;a<bookSize;a++)
              {
               count++;
               cumulative_vol=cumulative_vol+MarketBook[a].volume;
               if(MarketBook[a].volume>largest_vol){largest_vol=MarketBook[a].volume;}
               if(cumulative_vol>=def_cumulative_vol)
                 {last_accumulation_price=MarketBook[a].price;break;}
              }
           }
        }
     }

   return 0;
  }
//+------------------------------------------------------------------+
//|                            future use, checks                                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool CheckActualAccumulation(bool ask_true,double first_acc_price,double last_acc_price,long last_acc_volume,double diff_coeff)//diff coeff = min zna4enie deleniya novogo obiema na starii
  {

   MqlBookInfo MarketBook[];
   MarketBookGet(_Symbol,MarketBook);
   long cum_vol=0;

   if(ask_true)
     {
      for(int i=20;i>0;i--)
         //+------------------------------------------------------------------+
         //|                                                                  |
         //+------------------------------------------------------------------+
        {
         if(MarketBook[i].price==first_acc_price)
           {
            for(int a=i;a>0;a++)
               //+------------------------------------------------------------------+
               //|                                                                  |
               //+------------------------------------------------------------------+
              {
               cum_vol=cum_vol+MarketBook[a].volume;
               if(MarketBook[a].price==last_acc_price){break;}
              }
           }
        }
     }

   else
     {
      int BookSize=ArraySize(MarketBook);
      for(int i=20;i<BookSize;i++)

        {
         if(MarketBook[i].price==first_acc_price)
           {
            for(int a=i;a<BookSize;a++)

              {
               cum_vol=cum_vol+MarketBook[a].volume;
               if(MarketBook[a].price==last_acc_price){break;}
              }
           }
        }
     }
   if(cum_vol/last_acc_volume>diff_coeff)
     {return true;}
   else {return false;}

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool check_comission()
  {

   return true;
  }
//+------------------------------------------------------------------+
//|               remove expired orders                                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnTimer()
  {
   DeleteExpiredRegistryOrders();
   GetAccumulateAverageParameteres(curr_last,false);
   if(recover_expired_daily_ordes && !is_tester){RecoverExpiredSellOrders();}

//GetBookParameters(0.1);
//GetResultBookParam();
// Print("Small : ",curr_book.small_book_volume," Middle : ",curr_book.middle_book_volume," Large : ",curr_book.large_book_volume);
  }
//+------------------------------------------------------------------+
//|        add order to local register                                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

int AddOrderToRegistry(double price_open,double volume,int expiration_sec,int expiration_chain_sec,double strike_price,bool ask_true,bool boost_flag,datetime time_init,double check_near_range=0)
                                                                                                                                                                                                //+------------------------------------------------------------------+
  {
   int size=ArraySize(accumulate_registry);
   int fl_exist=0;
   if(check_near_range==0)
     {
      for(int x=0;x<size;x++)
        {
         if(accumulate_registry[x].price_open==0)
           {
            accumulate_registry[x].price_open=price_open;
            accumulate_registry[x].volume=volume;
            accumulate_registry[x].expiration_sec=expiration_sec;
            accumulate_registry[x].time=time_init;
            accumulate_registry[x].is_executed=0;
            accumulate_registry[x].is_covered=0;
            accumulate_registry[x].ask_true=ask_true;
            accumulate_registry[x].index_value=0;
            accumulate_registry[x].result_dev_value=0;
            accumulate_registry[x].pos_expiration_sec=0;
            accumulate_registry[x].pos_expiration_ticket=0;
            accumulate_registry[x].expiration_range_ticket=0;
            accumulate_registry[x].pos_expirate_range=0;
            accumulate_registry[x].expiration_chain_sec=expiration_chain_sec;
            accumulate_registry[x].execution_strike_price=strike_price;
            // if(lead_flag){accumulate_registry[x].lead_flag=1;}
            if(boost_flag){accumulate_registry[x].boost_flag=1;}
            //if(spread_boost_flag){accumulate_registry[x].spread_boost_flag=1;}
            Print("Add order to registry on ",price_open);
            return x;
            break;
           }
        }
     }
   else
     {
      int proceed_index=0;
      for(int x=0;x<size;x++)
        {
         if(accumulate_registry[x].price_open!=0)
           {
            if(accumulate_registry[x].price_open-price_open<check_near_range && accumulate_registry[x].price_open-price_open>0)
              {fl_exist=1;}
            if(price_open-accumulate_registry[x].price_open<check_near_range && accumulate_registry[x].price_open>0)
              {fl_exist=1;}
           }
         if(accumulate_registry[x].price_open==0 && fl_exist==0)
           {
            accumulate_registry[x].price_open=price_open;
            accumulate_registry[x].volume=volume;
            accumulate_registry[x].expiration_sec=expiration_sec;
            accumulate_registry[x].time=time_init;
            accumulate_registry[x].is_executed=0;
            accumulate_registry[x].is_covered=0;
            accumulate_registry[x].ask_true=ask_true;
            accumulate_registry[x].index_value=0;
            accumulate_registry[x].result_dev_value=0;
            accumulate_registry[x].pos_expiration_sec=0;
            accumulate_registry[x].pos_expiration_ticket=0;
            accumulate_registry[x].expiration_range_ticket=0;
            accumulate_registry[x].pos_expirate_range=0;
            accumulate_registry[x].expiration_chain_sec=expiration_chain_sec;
            accumulate_registry[x].execution_strike_price=strike_price;
            // if(lead_flag){accumulate_registry[x].lead_flag=1;}
            if(boost_flag){accumulate_registry[x].boost_flag=1;}
            //if(spread_boost_flag){accumulate_registry[x].spread_boost_flag=1;}
            Print("Add order to registry on ",price_open);
            proceed_index=x;

           }
        }
      if(fl_exist==1 && proceed_index!=0)
        {SetNullForAccumulateRegistry(proceed_index);return 1111;}
      if(fl_exist==0){return proceed_index;}
     }
   return 1111;
  }
//+------------------------------------------------------------------+
//|                 analyse local register to check execution rate of orders                                                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void GetAccumulateAverageParameteres(double price_last,bool higher)//higher = true - zna4it vishe ceni, buy_true = lower = buy higher = sell
  {
   double average_executed_index_value=0;
   int index_count=0;
   double highest_sell_ex=0;
   double lowest_buy_ex=1000000;

   double total_buy_executed_lot=0;
   double total_sell_executed_lot=0;

   double total_buy_pending_lot=0;
   double total_sell_pending_lot=0;

   int buy_transastions_count=0;
   int sell_transactions_count=0;

   int buy_pending_count=0;
   int sell_pending_count=0;

   double last_index_extremum=0;
   double last_resulst_dev_extremum=0;
// double cumulative_executed_price_path;
   double last_minimal_diff_pending_buy=10000;
   double last_minimal_diff_executed_buy=10000;

   double last_minimal_diff_pending_sell=10000;
   double last_minimal_diff_executed_sell=1000;

   double check_diff_pending_price_buy=0;
   double check_diff_executed_price_buy=0;

   double check_diff_pending_price_sell=0;
   double check_diff_executed_price_sell=0;

   double close_result_dev_sell=0;
   double close_result_dev_buy=0;
   double nearest_pending_buy_result_dev=0;
   double nearest_pending_sell_result_dev=0;

   double check_diff_close_pending_boost=10000;
   double close_pending_boost_price=0;

   near_buy_pending_flag_boost=false;
   near_buy_pending_flag_simple=false;
   near_sell_pending_flag_boost=false;
   near_sell_pending_flag_simple=false;

   double total_spread_executed_lot=0;
   double total_underwater_spread_executed_lot=0;
   int size=ArraySize(accumulate_registry);
   for(int i=0;i<size;i++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(i==100){continue;}
      if(accumulate_registry[i].price_open==0){continue;}
      if(accumulate_registry[i].spread_boost_flag==0)///////////////////COMMON MODULE
        {

         if(accumulate_registry[i].ask_true==false && accumulate_registry[i].is_executed==1 && accumulate_registry[i].is_covered==0)
           {if(accumulate_registry[i].price_open<lowest_buy_ex){lowest_buy_ex=accumulate_registry[i].price_open;last_index_extremum=accumulate_registry[i].index_value;last_index_extremum=accumulate_registry[i].index_value;last_resulst_dev_extremum=accumulate_registry[i].result_dev_value;}}

         //lower

         if(accumulate_registry[i].ask_true==false)//buy limit
           {
            if(accumulate_registry[i].is_executed==0)//not executed
              {
               buy_pending_count++;
               total_buy_pending_lot=total_buy_pending_lot+accumulate_registry[i].volume;
               if(price_last-accumulate_registry[i].price_open<last_minimal_diff_pending_buy)
                 {last_minimal_diff_pending_buy=price_last-accumulate_registry[i].price_open;check_diff_pending_price_buy=accumulate_registry[i].price_open;nearest_pending_buy_result_dev=accumulate_registry[i].result_dev_value;}
               if(accumulate_registry[i].boost_flag==1) ////boost
                 {
                  if(price_last-accumulate_registry[i].price_open<check_diff_close_pending_boost)
                    {check_diff_close_pending_boost=price_last-accumulate_registry[i].price_open;close_pending_boost_price=accumulate_registry[i].price_open;}
                 }
              }
            else if(accumulate_registry[i].is_covered==0)
              {
               total_buy_executed_lot=total_buy_executed_lot+accumulate_registry[i].volume;
               buy_transastions_count++;
               if(price_last-accumulate_registry[i].price_open<last_minimal_diff_executed_buy)
                 {close_result_dev_buy=accumulate_registry[i].result_dev_value;last_minimal_diff_executed_buy=price_last-accumulate_registry[i].price_open;check_diff_executed_price_buy=accumulate_registry[i].price_open;}

              }
            //last index extremum - zna4enie indexa na moment naimenshei pokupki ili prodaji
           }

         if(accumulate_registry[i].ask_true==true)
           {
            if(accumulate_registry[i].is_executed==0)
              {
               total_sell_pending_lot=total_sell_pending_lot+accumulate_registry[i].volume;
               if(accumulate_registry[i].price_open-price_last<last_minimal_diff_pending_sell)
                 {last_minimal_diff_pending_sell=accumulate_registry[i].price_open-price_last;check_diff_pending_price_sell=accumulate_registry[i].price_open;}
              }
           }

         //////////////////////////////////////////////////NEAR FLAGS
         if(accumulate_registry[i].ask_true==true){price_last=curr_ask;}
         else{price_last=curr_bid;}

         if(accumulate_registry[i].is_executed==0)
           {
            if(accumulate_registry[i].boost_flag==1)
              {
               if(accumulate_registry[i].price_open>=price_last && accumulate_registry[i].price_open-price_last<=5)
                 {
                  if(accumulate_registry[i].ask_true==true)
                    {near_sell_pending_flag_boost=true;}
                  else
                    {near_buy_pending_flag_boost=true;}
                 }
               if(accumulate_registry[i].price_open<=price_last && price_last-accumulate_registry[i].price_open<=5)
                 {
                  if(accumulate_registry[i].ask_true==true)
                    {near_sell_pending_flag_boost=true;}
                  else
                    {near_buy_pending_flag_boost=true;}
                 }
              }
            else
              {
               if(accumulate_registry[i].price_open>=price_last && accumulate_registry[i].price_open-price_last<=5)
                 {
                  if(accumulate_registry[i].ask_true==true)
                    {near_sell_pending_flag_simple=true;}
                  else
                    {near_buy_pending_flag_simple=true;}
                 }
               if(accumulate_registry[i].price_open<=price_last && price_last-accumulate_registry[i].price_open<=5)
                 {
                  if(accumulate_registry[i].ask_true==true)
                    {near_sell_pending_flag_simple=true;}
                  else
                    {near_buy_pending_flag_simple=true;}
                 }
              }
           }///////////////////////// END NEAR FLAGS
        }//END COMMON MODULE
      else ///////////////////////////////////SPREAD BOOST MODULE
        {
         if(accumulate_registry[i].is_executed==1 && accumulate_registry[i].is_covered==0)
           {
            total_spread_executed_lot=total_spread_executed_lot+accumulate_registry[i].volume;
            if(accumulate_registry[i].ask_true==true)
              {
               if(accumulate_registry[i].price_open>curr_ask)
                 {total_underwater_spread_executed_lot=total_underwater_spread_executed_lot+accumulate_registry[i].volume;}
              }
            else
              {
               if(accumulate_registry[i].price_open<curr_bid)
                 {total_underwater_spread_executed_lot=total_underwater_spread_executed_lot+accumulate_registry[i].volume;}
              }
           }

        }////////////////////////////////////END SPREAD BOOST
     }
   if(lowest_buy_ex!=1000000)
     {lowest_buy_price_executed=lowest_buy_ex;}
   else{lowest_buy_price_executed=0;}
   if(highest_sell_ex!=0)
     {highest_sell_price_executed=highest_sell_ex;}
   else{highest_sell_price_executed=0;}

   last_accumulate_buy_volume_executed=total_buy_executed_lot;
   last_accumulate_sell_volume_executed=total_sell_executed_lot;

   last_accumulate_buy_volume_pending=total_buy_pending_lot;
   last_accumulate_sell_volume_pending=total_sell_pending_lot;

   extremum_index=last_index_extremum;
   extremum_result_dev=last_resulst_dev_extremum;

   nearest_buy_executed=check_diff_executed_price_buy;
   nearest_sell_executed=check_diff_executed_price_sell;

   nearest_buy_pending=check_diff_pending_price_buy;
   nearest_sell_pending=check_diff_pending_price_sell;

   nearest_executed_buy_result_dev=close_result_dev_buy;
   nearest_executed_sell_result_dev=close_result_dev_sell;

   nearest_pending_buy_res_dev=nearest_pending_buy_result_dev;
   nearest_pending_sell_res_dev=nearest_pending_sell_result_dev;

   lot_parts_exec_buy=total_buy_executed_lot/1;
   lot_parts_exec_sell=total_sell_executed_lot/1;

   pending_buy_lot_total=total_buy_pending_lot;
   pending_sell_lot_total=total_sell_pending_lot;

   nearest_boost_price_pending=close_pending_boost_price;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SetExecutionToRegistryOrder(double price,bool ask_true,double volume) //checked
  {
   int index=GetAccumulateIndexByPrice(price,volume,true,true,ask_true);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(index!=1111)
     {
      if(accumulate_registry[index].ask_true==ask_true)
        {

         if(accumulate_registry[index].ask_true==false)
           {
            if(TimeCurrent()-accumulate_registry[index].time<accumulate_registry[index].expiration_chain_sec && accumulate_registry[index].execution_strike_price!=0)
              {

               AddOrderToRegistry(accumulate_registry[index].execution_strike_price,accumulate_registry[index].volume,0,accumulate_registry[index].expiration_chain_sec,accumulate_registry[index].price_open,true,true,accumulate_registry[index].time);
               PlaceOrder(accumulate_registry[index].execution_strike_price,accumulate_registry[index].volume,false,true,0);
              }

            SetNullForAccumulateRegistry(index);
           }
         if(accumulate_registry[index].ask_true==true)
           {
            if(TimeCurrent()-accumulate_registry[index].time<accumulate_registry[index].expiration_chain_sec && accumulate_registry[index].execution_strike_price!=0)
              {
               AddOrderToRegistry(accumulate_registry[index].execution_strike_price,accumulate_registry[index].volume,0,accumulate_registry[index].expiration_chain_sec,accumulate_registry[index].price_open,false,true,accumulate_registry[index].time);
               PlaceOrder(accumulate_registry[index].execution_strike_price,accumulate_registry[index].volume,true,true,0);

              }
            SetNullForAccumulateRegistry(index);
           }
         accumulate_registry[index].is_executed=1;accumulate_registry[index].execution_time=TimeCurrent();
        }

     }
   return index;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddTicketToRegistry(ulong ticket,double price,bool ask_true)
  {
   int size=ArraySize(accumulate_registry);
   for(int i=0;i<size;i++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(accumulate_registry[i].price_open==price && accumulate_registry[i].is_executed==0 && accumulate_registry[i].ask_true==ask_true)
        {accumulate_registry[i].ticket_open=ticket;Print("Set ticket for registry order for price ",accumulate_registry[i].price_open);}
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetAccumulateIndexByPrice(double price,double volume=0,bool unexecuted=false,bool ask_true_match=false,bool ask_true=true)//polu4aem nomer elementa massiva accumulate_registry po cene//esli return 1111 togds ni4ego ne nshlos
  {
   int size=ArraySize(accumulate_registry);
   for(int z=0;z<size;z++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      if(unexecuted)
        {if(accumulate_registry[z].is_executed==1){continue;}}
      if(ask_true_match)
        {if(accumulate_registry[z].ask_true!=ask_true){continue;}}
      if(volume!=0){if(accumulate_registry[z].volume!=volume){continue;}}
      if(accumulate_registry[z].price_open==price){return z;}
     }
   return 1111;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void DeleteExpiredRegistryOrders(bool stock_mode=true)
  {
   int fl_del=0;
   int size=ArraySize(accumulate_registry);
   int orders=0;
   for(int a=0;a<size;a++)
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
     {
      fl_del=0;
      if(accumulate_registry[a].price_open!=0 && accumulate_registry[a].is_executed==0 && accumulate_registry[a].price_open!=1111)
        {

         //////////////////////////////////////////////////////////////NULL for expiration parameters esli nado
         if(accumulate_registry[a].expiration_sec!=0)
           {
            if(TimeCurrent()-accumulate_registry[a].time>=accumulate_registry[a].expiration_sec)
              {
               fl_del=1;
              }
           }

         if(accumulate_registry[a].expiration_chain_sec!=0)
           {
            if(accumulate_registry[a].ask_true==false && TimeCurrent()-accumulate_registry[a].time>accumulate_registry[a].expiration_chain_sec)
              {fl_del=1;}
           }

        }
      if(fl_del==0){continue;}
      if(OrderSelect(accumulate_registry[a].ticket_open))
        {OrderDeleteAsync(accumulate_registry[a].ticket_open);Print("delete expired order on price ",accumulate_registry[a].price_open);}
      else
        {
         orders=OrdersTotal();
         for(int i=0;i<=orders;i++)
           {
            ulong ticket=OrderGetTicket(i);
            if(ticket!=0)
              {
               if(OrderSelect(ticket))
                 {
                  if(OrderGetString(ORDER_SYMBOL)!=_Symbol){continue;}
                  double pr=OrderGetDouble(ORDER_PRICE_OPEN);
                  if(pr==accumulate_registry[a].price_open)
                    {
                     OrderDeleteAsync(ticket);
                     Print("DELEXPREGISTRY: deleted expired registry order on price ",pr);
                    }
                 }
              }
           }
        }
      SetNullForAccumulateRegistry(a);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetNullForAccumulateRegistry(int single_index=1111,double price=0,bool spread_boost_match=false,bool ask_true_match=false,bool ask_true=false,int expiration_pos_ticket=0,int expirate_range_ticket=0)
  {
   if(single_index==1111)
     {
      int size=ArraySize(accumulate_registry);
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(price==0)
        {
         for(int i=0;i<size;i++)
           {
            if(ask_true_match && expiration_pos_ticket!=0)
              {
               if(accumulate_registry[i].ask_true!=ask_true || accumulate_registry[i].pos_expiration_ticket!=expiration_pos_ticket){continue;}
              }
            if(ask_true_match && expirate_range_ticket!=0)
              {
               if(accumulate_registry[i].ask_true!=ask_true || accumulate_registry[i].expiration_range_ticket!=expirate_range_ticket){continue;}
               Print("Expirate based on price ",accumulate_registry[i].price_open," order");
              }
            accumulate_registry[i].expiration_sec=0;
            accumulate_registry[i].price_open=0;
            accumulate_registry[i].volume=0;
            accumulate_registry[i].is_executed=0;
            accumulate_registry[i].is_covered=0;
            accumulate_registry[i].ticket_open=0;
            accumulate_registry[i].result_dev_value=0;
            accumulate_registry[i].boost_flag=0;
            accumulate_registry[i].spread_boost_flag=0;
            accumulate_registry[i].pos_expiration_sec=0;
            accumulate_registry[i].pos_expiration_ticket=0;
            accumulate_registry[i].pos_expirate_range=0;
            accumulate_registry[i].expiration_range_ticket=0;
            accumulate_registry[i].expiration_chain_sec=0;
            accumulate_registry[i].execution_strike_price=0;

            accumulate_registry[i].lead_flag=0;
            if(expiration_pos_ticket!=0 || expirate_range_ticket!=0){break;}
           }
        }
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(price!=0 && spread_boost_match)
        {
         for(int i=0;i<size;i++)
           {
            if(accumulate_registry[i].price_open==price && accumulate_registry[i].spread_boost_flag==1)
              {
               accumulate_registry[i].expiration_sec=0;
               accumulate_registry[i].price_open=0;
               accumulate_registry[i].volume=0;
               accumulate_registry[i].is_executed=0;
               accumulate_registry[i].is_covered=0;
               accumulate_registry[i].ticket_open=0;
               accumulate_registry[i].result_dev_value=0;
               accumulate_registry[i].boost_flag=0;
               accumulate_registry[i].spread_boost_flag=0;
               accumulate_registry[i].pos_expiration_sec=0;
               accumulate_registry[i].pos_expiration_ticket=0;
               accumulate_registry[i].pos_expirate_range=0;
               accumulate_registry[i].expiration_range_ticket=0;
               accumulate_registry[i].lead_flag=0;
               accumulate_registry[i].expiration_chain_sec=0;
               accumulate_registry[i].execution_strike_price=0;

              }
           }
        }
     }

   else
     {
      accumulate_registry[single_index].price_open=0;
      accumulate_registry[single_index].expiration_sec=0;
      accumulate_registry[single_index].index_value=0;
      accumulate_registry[single_index].result_dev_value=0;
      accumulate_registry[single_index].ticket_open=0;
      accumulate_registry[single_index].volume=0;
      accumulate_registry[single_index].is_executed=0;
      accumulate_registry[single_index].boost_flag=0;
      accumulate_registry[single_index].spread_boost_flag=0;
      accumulate_registry[single_index].pos_expiration_sec=0;
      accumulate_registry[single_index].pos_expiration_ticket=0;
      accumulate_registry[single_index].pos_expirate_range=0;
      accumulate_registry[single_index].expiration_range_ticket=0;
      accumulate_registry[single_index].expiration_chain_sec=0;
      accumulate_registry[single_index].execution_strike_price=0;
      accumulate_registry[single_index].lead_flag=0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteUnstructedOrders(bool registry_mode)
  {
   int orders=OrdersTotal();
   for(int i=0;i<orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      //+------------------------------------------------------------------+
      //|                                                                  |
      //+------------------------------------------------------------------+
      if(ticket!=0)
        {
         if(OrderSelect(ticket))
           {
            if(!registry_mode)
              {
               if(OrderGetString(ORDER_SYMBOL)!=_Symbol){continue;}
               double pr=OrderGetDouble(ORDER_PRICE_OPEN);
               if(pr!=info_pos_ask.price_open && pr!=info_pos_ask_sub1.price_open && pr!=info_pos_ask_sub2.price_open && pr!=info_pos_bid.price_open && pr!=info_pos_bid_sub1.price_open && pr!=info_pos_bid_sub2.price_open)
                 {
                  OrderDeleteAsync(ticket);
                  Print("DELunstr: deleted unstructed order on price ",pr);
                 }
              }
            else
              {
               if(OrderGetString(ORDER_SYMBOL)!=_Symbol){continue;}
               double pr=OrderGetDouble(ORDER_PRICE_OPEN);
               if(pr==info_pos_ask.price_open || pr==info_pos_bid.price_open){continue;}
               if(GetAccumulateIndexByPrice(pr,true)==1111)
                 {OrderDeleteAsync(ticket);Print("DELunstr: deleted unstructed accumulate order on price ",pr);}
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void SetNullForExpirateParameter(int value,bool ask_true,bool expirate_time_ticket=false,bool expirate_range_ticket=false)
  {
   int size=ArraySize(accumulate_registry);
   for(int t=0;t<size;t++)
     {
      if(accumulate_registry[t].ask_true==ask_true && accumulate_registry[t].is_executed==1)
        {
         if(expirate_time_ticket)
           {
            if(accumulate_registry[t].pos_expiration_ticket==value)
              {accumulate_registry[t].pos_expiration_ticket=0;}
           }
         if(expirate_range_ticket)
           {
            if(accumulate_registry[t].expiration_range_ticket==value)
              {accumulate_registry[t].expiration_range_ticket=0;}
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

void ExpirateExpiredPos(bool plus_expiration_too=true,bool simple_mode=true)
  {
   int fl_common=0;
   int fl_simple=0;
   double pr=0;
   int size=ArraySize(accumulate_registry);
   for(int i=0;i<size;i++)
     {

      if(curr_position==5 && accumulate_registry[i].pos_expiration_sec!=0 && accumulate_registry[i].ask_true==true && accumulate_registry[i].is_executed==1 && accumulate_registry[i].pos_expiration_ticket==0)
        {
         if(TimeCurrent()-accumulate_registry[i].execution_time<accumulate_registry[i].pos_expiration_sec){continue;}
         fl_common=0;
         fl_simple=0;
         pr=0;

         if(plus_expiration_too){fl_common=1;}
         else
           {
            if(curr_ask>accumulate_registry[i].price_open)
              {fl_common=1;}
           }

         if(simple_mode){fl_simple=1;pr=curr_bid+1;}
         else
           {
            //obrabot4ik variativnogo zakritiya
           }
         if(fl_common==1 && fl_simple==1)
           {
            accumulate_registry[i].pos_expiration_ticket=expiration_pos_ticket_count;

            AddOrderToRegistry(pr,accumulate_registry[i].volume,60,false,false,false,10000,accumulate_registry[i].pos_expiration_ticket);
            PlaceOrder(pr,accumulate_registry[i].volume,true,true,0);
            expiration_pos_ticket_count++;
            Print("Set TIME expiration for order priced by ",accumulate_registry[i].price_open," for price ",pr);
           }
        }

      if(curr_position==6 && accumulate_registry[i].ask_true==false && accumulate_registry[i].is_executed==1 && accumulate_registry[i].pos_expiration_ticket==0)
        {
         if(TimeCurrent()-accumulate_registry[i].execution_time<accumulate_registry[i].pos_expiration_sec){continue;}
         fl_common=0;
         fl_simple=0;
         pr=0;

         if(plus_expiration_too){fl_common=1;}
         else
           {
            if(curr_bid<accumulate_registry[i].price_open)
              {fl_common=1;}
           }

         if(simple_mode){fl_simple=1;pr=curr_ask-1;}
         else
           {
            //obrabot4ik variativnogo zakritiya
           }
         if(fl_common==1 && fl_simple==1)
           {
            accumulate_registry[i].pos_expiration_ticket=expiration_pos_ticket_count;

            AddOrderToRegistry(pr,accumulate_registry[i].volume,60,true,true,false,10000,accumulate_registry[i].pos_expiration_ticket);
            PlaceOrder(pr,accumulate_registry[i].volume,false,true,0);
            Print("Set TIME expiration for order priced by ",accumulate_registry[i].price_open," for price ",pr);
            expiration_pos_ticket_count++;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
   return;
   SymbolInfoTick(_Symbol,last_tick);

   MqlTick tick[1];
   CopyTicks(_Symbol,tick,COPY_TICKS_TRADE,0,1);
   Print("Vol : ",tick[0].volume,"Time : ",tick[0].time_msc);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RecoverExpiredSellOrders()
  {
   MqlDateTime curr_time;
   MqlDateTime check_time;
   TimeToStruct(TimeCurrent(),curr_time);
   int size=ArraySize(accumulate_registry);
   for(int i=0;i<size;i++)
     {
      if(accumulate_registry[i].is_executed==0 && accumulate_registry[i].ask_true==true && accumulate_registry[i].ticket_open!=0)
        {
         if(accumulate_registry[i].ask_true==true)
           {
            
            if(!IsActualOrder(accumulate_registry[i].price_open))
              {
               PlaceOrder(accumulate_registry[i].price_open,accumulate_registry[i].volume,false,true,0);Print("Recovered yesterday order on price ",accumulate_registry[i].price_open);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MarginControl()
  {
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)<critical_margin_level)
     {low_margin=true;}
   else {low_margin=false;}

  }
//+------------------------------------------------------------------+
bool IsActualOrder(double price)
{
   int fl=0;
   int orders=OrdersTotal();
   for(int i=0;i<=orders;i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket!=0)
        {
        if(OrderSelect(ticket)) 
        {
        
         
        
         if(OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_SELL_LIMIT && OrderGetDouble(ORDER_PRICE_OPEN)==price)
           {
            fl=1;
           }
         }
       }
     }
   if(fl==1){return true;}
   return false;
}

//void executeTestOrders()
//  {
//   int size=ArraySize(accumulate_registry);
//   for(int i=0; i<size;i++)
//     {
//     accumulate_info c = accumulate_registry[i];
//      if(c.is_executed==0)
//        {
//         if(c.ask_true==true && last_tick.last>=c.price_open && c.is_covered==0)
//           {
//            PlaceOrder(c.price_open, c.volume, false, true, 0);
//            c.is_covered=1;
//            GetAccumulateAverageParameteres(curr_last, false);
//           }
//         else if(accumulate_registry[i].ask_true==false && last_tick.last<=accumulate_registry[i].price_open && accumulate_registry[i].is_covered==0)
//           {
//            PlaceOrder(accumulate_registry[i].price_open,accumulate_registry[i].volume,true,true,0);accumulate_registry[i].is_covered=1;
//            GetAccumulateAverageParameteres(curr_last, false);
//           }
//
//        }
//     }
//  }

void executeTestOrders() {
   int size = ArraySize(accumulate_registry);
   for (int i=0; i<size; ++i) {
        accumulate_info c = accumulate_registry[i];
        int buy_multiplier = c.ask_true ? 1 : -1;
        if(!c.is_executed  && !c.is_covered && buy_multiplier * last_tick.last >= c.price_open * buy_multiplier) {
            c.is_covered = 1;
            PlaceOrder(c.price_open, c.volume, !c.ask_true, true, 0);
            GetAccumulateAverageParameteres(curr_last, false);
        }          
  }
}

//---

//+------------------------------------------------------------------+
