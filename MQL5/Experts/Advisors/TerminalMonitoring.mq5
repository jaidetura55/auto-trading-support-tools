//+------------------------------------------------------------------+
//|                                           TerminalMonitoring.mq5 |
//|                               Copyright 2019, Teruhiko Kusunoki. |
//|                                        https://www.terukusu.org/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Teruhiko Kusunoki."
#property link      "https://www.terukusu.org/"
#property version   "1.00"

input int INTERVAL=15;
input string MAIL_SUBJECT="MetaTrader Monitoring";

// EA名とmagicのマッピング(magic_01〜magic_05の５個まで設定できる)
input int magic_01=0;
input string magic_01_name="noname";

input int magic_02=0;
input string magic_02_name="noname";

input int magic_03=0;
input string magic_03_name="noname";

input int magic_04=0;
input string magic_04_name="noname";

input int magic_05=0;
input string magic_05_name="noname";
//+------------------------------------------------------------------+
//| マジックナンバーとEA名のマップ要素                                                                 |
//+------------------------------------------------------------------+
struct MagicInfo
  {
   int               magic;
   char              name[128];
  };

// 定数
const int arr_reserve=20;

//グローバル変数
MagicInfo magic_list[5];
ulong tickets_old[];
ulong tickets_now[];
ulong tickets_added[];
ulong tickets_deleted[];
ulong ut_old=0;
datetime last_OnTimer_exec=0;
datetime test_begin=0;
ulong test_tickets[5];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ArrayResize(tickets_old,0,arr_reserve);
   ArrayResize(tickets_now,0,arr_reserve);
   ArrayResize(tickets_added,0,arr_reserve);
   ArrayResize(tickets_deleted,0,arr_reserve);

   magic_list[0].magic=magic_01;
   StringToCharArray(magic_01_name,magic_list[0].name);

   magic_list[1].magic=magic_02;
   StringToCharArray(magic_02_name,magic_list[1].name);

   magic_list[2].magic=magic_03;
   StringToCharArray(magic_03_name,magic_list[2].name);

   magic_list[3].magic=magic_04;
   StringToCharArray(magic_04_name,magic_list[3].name);

   magic_list[4].magic=magic_05;
   StringToCharArray(magic_05_name,magic_list[4].name);

   if(MQL_TESTER)
     {
      test_begin=TimeCurrent();
      ArrayInitialize(test_tickets,0);
     }

   EventSetTimer(INTERVAL);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

//--- ストラテジテスターで実行される場合にTimerをシミュレート
   if(MQL_TESTER)
     {
      if(TimeCurrent()-last_OnTimer_exec>INTERVAL)
        {
         OnTimer();
         last_OnTimer_exec=TimeCurrent();
        }
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   PerformMonitoring();
  }
//+------------------------------------------------------------------+
//| PerformMonitoring                                                |
//+------------------------------------------------------------------+
void PerformMonitoring()
  {
   int i,num_added,num_deleted;
   ulong ticket,open_ticket,close_ticket;
   double Bid,Ask;

   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   Bid = last_tick.bid;
   Ask = last_tick.ask;

   ArrayResize(tickets_now,0,arr_reserve);
   ArrayResize(tickets_added,0,arr_reserve);
   ArrayResize(tickets_deleted,0,arr_reserve);

   ulong nowlocal_ut=TimeLocal();
   int filehandle;

//ハートビートファイルの更新
   filehandle=FileOpen("terminal_monitoring.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI,0);

   if(filehandle!=INVALID_HANDLE)
     {
      //Print("FileOpene Finish");
      FileSeek(filehandle,0,SEEK_END);
      FileWriteString(filehandle,(string)(long)TimeGMT()+",");
      FileWriteString(filehandle,(string)(long)TimeCurrent()+",");
      FileWriteString(filehandle,(string)Bid+",");
      FileWriteString(filehandle,(string)Ask+",");
      FileWriteString(filehandle,(string)SymbolInfoInteger(Symbol(),SYMBOL_SPREAD)+",");
      FileWriteString(filehandle,(string)TerminalInfoInteger(TERMINAL_PING_LAST)+",");
      FileWriteString(filehandle,DoubleToString(pricePerPip(),4)+",");
      FileWriteString(filehandle,Symbol()+"\n");
      FileClose(filehandle);
      //Print("FileWriteString Finish");
     }
   else Print("Operation FileOpen failed, error ",GetLastError());

   if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
    // 口座がヘッジモードではないので、↓のポジション関連の処理は正しく動作しないので行わない。
    return;
   }

//現在のポジションを取得する
   for(i=0; i<PositionsTotal(); i++)
     {
      ticket=PositionGetTicket(i);
      if(!ticket) continue;

      push(tickets_now,ticket);

      if(!in_array(tickets_old,ticket))
        {
         push(tickets_added,ticket);
        }
     }
//削除されたポジションのチェック
   for(i=0; i<ArraySize(tickets_old); i++)
     {
      ticket=tickets_old[i];
      if(!in_array(tickets_now,ticket))
        {
         push(tickets_deleted,ticket);
        }
     }
// ポジションに変化があった場合の処理
   num_added=ArraySize(tickets_added);
   num_deleted=ArraySize(tickets_deleted);
   string msg="";

   for(i=0; i<num_added; i++)
     {
      ticket=tickets_added[i];
      if(!PositionSelectByTicket(ticket)) continue;

      msg = msg + magic2eaname(PositionGetInteger(POSITION_MAGIC)) + " ";
      msg = msg + "新規 #" + (string)ticket + " ";
      msg = msg + PositionTypeToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)) + " ";
      msg = msg + DoubleToString(PositionGetDouble(POSITION_VOLUME),2) + " ";
      msg = msg + PositionGetString(POSITION_SYMBOL) + ", 価格 " + dts2(PositionGetDouble(POSITION_PRICE_OPEN)) + " ";
      msg = msg + "sl: " + dts2(PositionGetDouble(POSITION_SL)) + " ";
      msg = msg + "tp: " + dts2(PositionGetDouble(POSITION_TP)) + ", ";
      msg = msg + "他: " + (string)(PositionsTotal() - 1) + "\n";
     }

   for(i=0; i<num_deleted; i++)
     {
      ticket=tickets_deleted[i];

      open_ticket=FindOpenDealByPostionId(ticket);
      close_ticket=FindCloseDealByPostionId(ticket);

      if(!open_ticket || !close_ticket) continue;

      msg=msg+magic2eaname(HistoryDealGetInteger(open_ticket,DEAL_MAGIC))+" ";
      msg = msg + "決済 #" + (string)ticket + " ";
      msg = msg + DealTypeToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(open_ticket, DEAL_TYPE)) + " ";
      msg = msg + DoubleToString(HistoryDealGetDouble(close_ticket, DEAL_VOLUME),2) + " ";
      msg = msg + HistoryDealGetString(open_ticket, DEAL_SYMBOL) + ", 価格 " + dts2(HistoryDealGetDouble(open_ticket, DEAL_PRICE)) + " ";
      msg = msg + "→ " + dts2(HistoryDealGetDouble(close_ticket, DEAL_PRICE)) + ", ";
      msg = msg + "損益: " + DoubleToString(HistoryDealGetDouble(close_ticket, DEAL_PROFIT),2) + " ";
      msg = msg + "口座残高: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + ", ";
      msg = msg + "他: " + (string)(PositionsTotal()) + "\n";
     }
//Print("msg="+msg);

   if(StringLen(msg)>0)
     {
      //メール送信
      if(TerminalInfoInteger(TERMINAL_EMAIL_ENABLED) && StringLen(MAIL_SUBJECT))
        {
         SendMail(MAIL_SUBJECT,msg);
        }

      // 外部の監視系のためにオーダー情報を書き出す。ファイル削除は外部に任せてここでは追記するのみ。
      //Print("FileOpening..");
      filehandle=FileOpen("order_status",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
      if(filehandle!=INVALID_HANDLE)
        {
         //Print("FileOpene Finish");
         FileSeek(filehandle,0,SEEK_END);
         FileWriteString(filehandle,msg);
         FileClose(filehandle);
         //Print("FileWriteString Finish");
        }
      else Print("Operation FileOpen failed, error ",GetLastError());
     }

//現在のチケット番号とチェック時間を保存する
   ArrayResize(tickets_old,ArraySize(tickets_now),arr_reserve);
   for(i=0; i<ArraySize(tickets_now); i++) tickets_old[i]=tickets_now[i];
   ut_old=nowlocal_ut;
  }
//小数点を適切に切る
string dts2(double val)
  {
   if(val < 10) return(DoubleToString(val,4));
   else return(DoubleToString(val,2));
  }
//+------------------------------------------------------------------+
//| 現在の通貨ペアの1pipあたりの値を取得します                                                |
//+------------------------------------------------------------------+
double pricePerPip()
  {
   int digits=_Digits;

   if(digits<=3)
     {
      return(0.01);
     }
   else if(digits>=4)
     {
      return(0.0001);
     }
   else return(0);
  }
//PositionTypeの値を文字列で返す
string PositionTypeToString(int type)
  {
   if(type == POSITION_TYPE_BUY)            return("BUY");
   else if(type == POSITION_TYPE_SELL)      return("SELL");
   else return("unknown");
  }
//DealTypeの値を文字列で返す
string DealTypeToString(int type)
  {
   if(type == DEAL_TYPE_BUY)            return("BUY");
   else if(type == DEAL_TYPE_SELL)      return("SELL");
   else return("unknown");
  }
//配列の最後に値を追加する
int push(ulong &ary[],ulong val)
  {
   int len=ArraySize(ary);
   ArrayResize(ary,(len+1),arr_reserve);
   ary[len]=val;
   return(ArraySize(ary));
  }
//配列内に指定した値が存在するか
bool in_array(ulong &ary[],ulong val)
  {
   bool res = false;
   for(int i=0; i<ArraySize(ary); i++)
     {
      if(ary[i]==val)
        {
         res=true;
         break;
        }
     }
   return(res);
  }
//マジックナンバーからEA名を取得する
string magic2eaname(long magic)
  {
   MagicInfo info;

   if(magic == 0) return("N/A");

   info=FindMagic(magic);
   if(info.magic != 0) return CharArrayToString(info.name);

   return("EA" + DoubleToString(magic,0));
  }
//+------------------------------------------------------------------+
//| マジックナンバーからEA情報を取得します                                                                 |
//+------------------------------------------------------------------+
MagicInfo FindMagic(ulong magic)
  {
   MagicInfo result;
   result.magic=0;
   result.name[0]=0;
   if(magic==0)
     {
      return result;
     }

   for(int i=0; i<ArraySize(magic_list); i++)
     {
      if(magic_list[i].magic==magic)
        {
         result=magic_list[i];
         break;
        }
     }

   return result;
  }
//+------------------------------------------------------------------+
//| FindCloseDealByPostionId                                         |
//+------------------------------------------------------------------+
ulong FindCloseDealByPostionId(ulong position_id)
  {
   if(!HistorySelectByPosition(position_id)) return 0;

   int num_deal=HistoryDealsTotal();

   for(int i=0; i<num_deal; i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket,DEAL_ENTRY)==DEAL_ENTRY_OUT)
        {
         return ticket;
        }
     }

   return 0;
  }
//+------------------------------------------------------------------+
//| FindOpenDealByPostionId                                          |
//+------------------------------------------------------------------+
ulong FindOpenDealByPostionId(ulong position_id)
  {
   if(!HistorySelectByPosition(position_id)) return 0;

   int num_deal=HistoryDealsTotal();

   for(int i=0; i<num_deal; i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket,DEAL_ENTRY)==DEAL_ENTRY_IN)
        {
         return ticket;
        }
     }

   return 0;
  }
//+------------------------------------------------------------------+
