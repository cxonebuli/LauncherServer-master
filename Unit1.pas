unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Grids, Vcl.ExtCtrls, System.Generics.Collections,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, inifiles, System.SyncObjs;

type
tEventListener = procedure(event: integer);cdecl;
tClientListener = procedure(ztype: PAnsiChar; value: PAnsiChar);cdecl;
tServerListener = procedure(id: integer; added: boolean);cdecl;
tServerListenerName = procedure(id: integer; value: PAnsiChar);cdecl;
tServerListenerAttr = procedure(id: integer; name: PAnsiChar; value: PAnsiChar);cdecl;
tServerListenerCap = procedure(id: integer; cap0: integer; cap1: integer);cdecl;
tServerListenerState = procedure(id: integer; value: integer);cdecl;
tServerListenerPlayers = procedure(id: integer; value: integer);cdecl;
tServerListenerAddr = procedure(id: integer; ip: PAnsiChar; port: integer);cdecl;

  TServer = class
    public
      row:integer;
      name:string;
      state:integer;
      map,mode,pb:string;
      players,max_players:integer;
      ip:string;
      port:integer;
  end;

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    serverlist: TStringGrid;
    UpdateTimer: TTimer;
    IdHTTP1: TIdHTTP;
    ReconnectTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ReconnectTimerTimer(Sender: TObject);
    procedure UpdateTimerTimer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  DllHandle:THandle;
  mutex:TMutex;
  servers: TObjectDictionary<integer, TServer>;
  in_serverlist:bool;

implementation

var
ZLO_Init:procedure(); cdecl;
ZLO_ListenGOS: function(): boolean; cdecl;
//Events
ZLO_SetEventListener:procedure(l: tEventListener); cdecl;
ZLO_SetClientListener:procedure(l: tClientListener); cdecl;
ZLO_SetServerListener:procedure(l: tServerListener); cdecl;
ZLO_SetServerListenerName:procedure(l: tServerListenerName); cdecl;
ZLO_SetServerListenerAttr:procedure(l: tServerListenerAttr); cdecl;
ZLO_SetServerListenerCap:procedure(l: tServerListenerCap); cdecl;
ZLO_SetServerListenerState:procedure(l: tServerListenerState); cdecl;
ZLO_SetServerListenerPlayers:procedure(l: tServerListenerPlayers); cdecl;
ZLO_SetServerListenerAddr:procedure(l: tServerListenerAddr); cdecl;
//Client
ZLO_ConnectMClient:function(addr:PAnsiChar):boolean; cdecl;
ZLO_AuthClient:procedure(mail,pass:PAnsiChar); cdecl;
ZLO_GetServerList:procedure(); cdecl;
ZLO_SelectServer:procedure(id: integer); cdecl;
ZLO_RunClient:function(): boolean; cdecl;
ZLO_GetID:function(): integer; cdecl;
//
ZLO_ListenServer:function(): boolean; cdecl;
ZLO_ConnectMServer:function(addr:PAnsiChar):boolean; cdecl;
//
ZLO_Close:procedure(); cdecl;

{$R *.dfm}

function MapName(m:string):string;
begin
if m='MP_001' then
result:='Grand Bazaar'
else if m='MP_003' then
result:='Teheran Highway'
else if m='MP_007' then
result:='Caspian Border'
else if m='MP_011' then
result:='Seine Crossing'
else if m='MP_012' then
result:='Operation Firestorm'
else if m='MP_013' then
result:='Damavand Peak'
else if m='MP_017' then
result:='Noshahar Canals'
else if m='MP_018' then
result:='Kharg Island'
else if m='MP_Subway' then
result:='Operation Metro'
else if m='XP1_001' then
result:='Strike at Karkand'
else if m='XP1_002' then
result:='Gulf of Oman'
else if m='XP1_003' then
result:='Sharqi Peninsula'
else if m='XP1_004' then
result:='Wake Island'
else if m='XP2_Factory' then
result:='Scrapmetal'
else if m='XP2_Office' then
result:='Operation 925'
else if m='XP2_Palace' then
result:='Donya Fortress'
else if m='XP2_Skybar' then
result:='Ziba Tower'
else if m='XP3_Desert' then
result:='Bandar Desert'
else if m='XP3_Alborz' then
result:='Alborz Mountains'
else if m='XP3_Shield' then
result:='Armored Shield'
else if m='XP3_Valley' then
result:='Death Valley'
else if m='XP4_Quake' then
result:='Epicenter'
else if m='XP4_FD' then
result:='Markaz Monolith'
else if m='XP4_Parl' then
result:='Azadi Palace'
else if m='XP4_Rubble' then
result:='Talah Market'
else if m='XP5_001' then
result:='Operation Riverside'
else if m='XP5_002' then
result:='Nebandan Flats'
else if m='XP5_003' then
result:='Kiasar Railroad'
else if m='XP5_004' then
result:='Sabalan Pipeline'
else
result:=m;
end;

procedure ClearServers();
var
id:integer;
begin
mutex.Acquire;
form1.serverlist.RowCount:=1;
servers.Clear;
mutex.Release;
end;

procedure ReDraw;
var
i,id:integer;
begin
if in_serverlist then
exit;
i:=1;
form1.serverlist.RowCount:=servers.Count + 1;
if servers.Count>0 then
for id in servers.Keys do
begin
servers.Items[id].row:=i;
form1.serverlist.Rows[i][0]:=servers.Items[id].name;
case servers.Items[id].state of
1:form1.serverlist.Rows[i][1]:='Initializing';
130:form1.serverlist.Rows[i][1]:='Pre game';
131:form1.serverlist.Rows[i][1]:='In game';
141:form1.serverlist.Rows[i][1]:='Post game';
end;
form1.serverlist.Rows[i][2]:=servers.Items[id].map;
form1.serverlist.Rows[i][3]:=servers.Items[id].mode;
form1.serverlist.Rows[i][4]:=inttostr(servers.Items[id].players);
form1.serverlist.Rows[i][5]:=inttostr(servers.Items[id].max_players);
form1.serverlist.Rows[i][6]:=servers.Items[id].pb;
inc(i);
end;
if form1.serverlist.RowCount>1 then
form1.serverlist.FixedRows:=1;
end;

procedure EventListener(event: integer);cdecl;
begin
case event of
0:
begin
form1.Memo1.Lines.Add('Auth success');
ClearServers();
in_serverlist:=false;
end;
2:begin form1.Memo1.Lines.Add('Old Launcher.dll');form1.Button1.Enabled:=false;form1.UpdateTimer.Enabled:=true;end;
29:form1.Memo1.Lines.Add('Server connected');
30:form1.Memo1.Lines.Add('Server auth success');
31:form1.Memo1.Lines.Add('Server auth error');
32:begin form1.Memo1.Lines.Add('Disconnected from master, will reconnect in 5sec');form1.button1.Enabled:=true;ClearServers();form1.ReconnectTimer.Enabled:=true;end;
33:form1.Memo1.Lines.Add('Master timeout and disconnected');
34:form1.Memo1.Lines.Add('Dll check ok');
35:form1.Memo1.Lines.Add('Server disconnected');
else
form1.Memo1.Lines.Add('Event: ' + inttostr(event));
end
end;

procedure ServerListener(id: integer; added: boolean);cdecl;
begin
mutex.Acquire;
if added and not servers.ContainsKey(id) then
servers.Add(id,TServer.Create())
else if servers.ContainsKey(id) then
servers.Remove(id);
ReDraw;
mutex.Release;
end;

procedure ServerListenerName(id: integer; value: PAnsiChar);cdecl;
var
i:integer;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].name:=value;
if not in_serverlist then
form1.serverlist.Cols[0][servers.Items[id].row]:=value;
end;
mutex.Release;
end;

procedure ServerListenerAttr(id: integer; name: PAnsiChar; value: PAnsiChar);cdecl;
begin
if (name<>'level')and(name<>'mode')and(name<>'punkbuster') then
exit;
mutex.Acquire;
if servers.ContainsKey(id) then
begin
if name='level' then
begin
servers.Items[id].map:=MapName(value);
if not in_serverlist then
form1.serverlist.Cols[2][servers.Items[id].row]:=MapName(value);
end
else if name='mode' then
begin
servers.Items[id].mode:=value;
if not in_serverlist then
form1.serverlist.Cols[3][servers.Items[id].row]:=value;
end
else if name='punkbuster' then
begin
servers.Items[id].pb:=value;
if not in_serverlist then
form1.serverlist.Cols[6][servers.Items[id].row]:=value;
end;
end;
mutex.Release;
end;

procedure ServerListenerCap(id: integer; cap0: integer; cap1: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].max_players:=cap0;
if not in_serverlist then
form1.serverlist.Cols[5][servers.Items[id].row]:=inttostr(cap0);
end;
mutex.Release;
end;

procedure ServerListenerState(id: integer; value: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].state:=value;
if not in_serverlist then
case value of
1:form1.serverlist.Cols[1][servers.Items[id].row]:='Initializing';
130:form1.serverlist.Cols[1][servers.Items[id].row]:='Pre game';
131:form1.serverlist.Cols[1][servers.Items[id].row]:='In game';
141:form1.serverlist.Cols[1][servers.Items[id].row]:='Post game';
end;
end;
mutex.Release;
end;

procedure ServerListenerPlayers(id: integer; value: integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].players:=value;
if not in_serverlist then
form1.serverlist.Cols[4][servers.Items[id].row]:=inttostr(value);
end;
mutex.Release;
end;

procedure ServerListenerAddr(id: integer; ip: PAnsiChar; port:integer);cdecl;
begin
mutex.Acquire;
if servers.ContainsKey(id) then
begin
servers.Items[id].ip:=ip;
servers.Items[id].port:=port;
end;
mutex.Release;
end;

procedure InitLib();
begin
DllHandle:=LoadLibrary('Launcher.dll');
if Dllhandle<>0 then
begin
@ZLO_Init:=GetProcAddress(DllHandle, 'ZLO_Init');
@ZLO_ListenGOS:=GetProcAddress(DllHandle, 'ZLO_ListenGOS');
//Events
@ZLO_SetEventListener:=GetProcAddress(DllHandle, 'ZLO_SetEventListener');
@ZLO_SetClientListener:=GetProcAddress(DllHandle, 'ZLO_SetClientListener');
@ZLO_SetServerListener:=GetProcAddress(DllHandle, 'ZLO_SetServerListener');
@ZLO_SetServerListenerName:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerName');
@ZLO_SetServerListenerAttr:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerAttr');
@ZLO_SetServerListenerCap:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerCap');
@ZLO_SetServerListenerState:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerState');
@ZLO_SetServerListenerPlayers:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerPlayers');
@ZLO_SetServerListenerAddr:=GetProcAddress(DllHandle, 'ZLO_SetServerListenerAddr');
//Client
@ZLO_ConnectMClient:=GetProcAddress(DllHandle, 'ZLO_ConnectMClient');
@ZLO_AuthClient:=GetProcAddress(DllHandle, 'ZLO_AuthClient');
@ZLO_GetServerList:=GetProcAddress(DllHandle, 'ZLO_GetServerList');
@ZLO_SelectServer:=GetProcAddress(DllHandle, 'ZLO_SelectServer');
@ZLO_RunClient:=GetProcAddress(DllHandle, 'ZLO_RunClient');
@ZLO_GetID:=GetProcAddress(DllHandle, 'ZLO_GetID');
//Server
@ZLO_ListenServer:=GetProcAddress(DllHandle, 'ZLO_ListenServer');
@ZLO_ConnectMServer:=GetProcAddress(DllHandle, 'ZLO_ConnectMServer');
//
@ZLO_Close:=GetProcAddress(DllHandle, 'ZLO_Close');
//
ZLO_Init();
ZLO_SetEventListener(@EventListener);
ZLO_SetServerListener(@ServerListener);
ZLO_SetServerListenerName(@ServerListenerName);
ZLO_SetServerListenerAttr(@ServerListenerAttr);
ZLO_SetServerListenerCap(@ServerListenerCap);
ZLO_SetServerListenerState(@ServerListenerState);
ZLO_SetServerListenerPlayers(@ServerListenerPlayers);
ZLO_SetServerListenerAddr(@ServerListenerAddr);
if not ZLO_ListenGOS() then
begin
showmessage('Cant open port for GOS, you can see servers, but cannot connect');
form1.memo1.lines.add('Cant open port for GOS, you can see servers, but cannot connect');
end;
if not ZLO_ListenServer() then
begin
showmessage('Cant open port for server, its fatal');
form1.memo1.lines.add('Cant open port for server, its fatal');
end;
end
else
begin
showmessage('Some error with Launcher.dll');
Application.Terminate;
end;
end;

procedure UpdateLib();
var
Buffer: TFileStream;
HttpClient: TIdHttp;
begin
form1.Memo1.Lines.Add('Updating dll');
if DllHandle<>0 then
begin
ZLO_Close();
FreeLibrary(DllHandle);
end;
try
deletefile('Launcher.dll');
Buffer:=TFileStream.Create('Launcher.dll', fmCreate or fmShareDenyWrite);
except
begin
Buffer.Free;
form1.Memo1.Lines.Add('Error updating dll');
exit;
end;
end;
HttpClient:=TIdHttp.Create(nil);
try
HttpClient.Get('http://zlofenix.org/bf3/Launcher.dll', Buffer);
except
begin
form1.Memo1.Lines.Add('Error updating dll');
Buffer.Free;
HttpClient.Free;
exit;
end;
end;
Buffer.Free;
HttpClient.Free;
form1.Memo1.Lines.Add('Dll updated');
InitLib;
ClearServers();
if ZLO_ConnectMClient('zlofenix.org') then
begin
form1.button1.Enabled:=false;
form1.Memo1.Clear;
form1.Memo1.Lines.Add('Connected to master');
end
else
form1.Memo1.Lines.Add('Cant connect to master');
end;

procedure TForm1.Button1Click(Sender: TObject);
var
ini:tinifile;
begin
ini:=tinifile.Create(GetCurrentDir+'/LauncherS.ini');
ini.WriteInteger('Form','Left',form1.Left);
ini.WriteInteger('Form','Top',form1.Top);
ini.WriteInteger('Form','Height',form1.Height);
ini.WriteInteger('Form','Width',form1.Width);
ini.WriteInteger('Cols','0',serverlist.ColWidths[0]);
ini.WriteInteger('Cols','1',serverlist.ColWidths[1]);
ini.WriteInteger('Cols','2',serverlist.ColWidths[2]);
ini.WriteInteger('Cols','3',serverlist.ColWidths[3]);
ini.WriteInteger('Cols','4',serverlist.ColWidths[4]);
ini.WriteInteger('Cols','5',serverlist.ColWidths[5]);
ini.WriteInteger('Cols','6',serverlist.ColWidths[6]);
ini.Free;
ReconnectTimer.Enabled:=false;
ClearServers();
if ZLO_ConnectMServer('zlofenix.org') then
begin
button1.Enabled:=false;
Memo1.Clear;
Memo1.Lines.Add('Connected to master');
end
else
Memo1.Lines.Add('Cant connect to master');
end;

procedure TForm1.FormCreate(Sender: TObject);
var
ini:tinifile;
begin
servers:=TObjectDictionary<integer, TServer>.create();
mutex:=TMutex.Create();
if not fileexists('Launcher.dll') then
begin
showmessage('Launcher.dll not found');
Application.Terminate;
exit;
end;
ini:=tinifile.Create(GetCurrentDir+'/LauncherS.ini');
form1.Left:=ini.ReadInteger('Form','Left',0);
form1.Top:=ini.ReadInteger('Form','Top',0);
form1.Height:=ini.ReadInteger('Form','Height',347);
form1.Width:=ini.ReadInteger('Form','Width',871);
serverlist.ColWidths[0]:=ini.ReadInteger('Cols','0',189);
serverlist.ColWidths[1]:=ini.ReadInteger('Cols','1',58);
serverlist.ColWidths[2]:=ini.ReadInteger('Cols','2',134);
serverlist.ColWidths[3]:=ini.ReadInteger('Cols','3',136);
serverlist.ColWidths[4]:=ini.ReadInteger('Cols','4',49);
serverlist.ColWidths[5]:=ini.ReadInteger('Cols','5',64);
serverlist.ColWidths[6]:=ini.ReadInteger('Cols','6',49);
ini.Free;
serverlist.Rows[0][0]:='Server name';
serverlist.Rows[0][1]:='State';
serverlist.Rows[0][2]:='Map';
serverlist.Rows[0][3]:='Gametype';
serverlist.Rows[0][4]:='Players';
serverlist.Rows[0][5]:='Max players';
serverlist.Rows[0][6]:='PB';
InitLib();
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
ini:tinifile;
begin
ini:=tinifile.Create(GetCurrentDir+'/LauncherS.ini');
ini.WriteInteger('Form','Left',form1.Left);
ini.WriteInteger('Form','Top',form1.Top);
ini.WriteInteger('Form','Height',form1.Height);
ini.WriteInteger('Form','Width',form1.Width);
ini.WriteInteger('Cols','0',serverlist.ColWidths[0]);
ini.WriteInteger('Cols','1',serverlist.ColWidths[1]);
ini.WriteInteger('Cols','2',serverlist.ColWidths[2]);
ini.WriteInteger('Cols','3',serverlist.ColWidths[3]);
ini.WriteInteger('Cols','4',serverlist.ColWidths[4]);
ini.WriteInteger('Cols','5',serverlist.ColWidths[5]);
ini.WriteInteger('Cols','6',serverlist.ColWidths[6]);
ini.Free;
if DllHandle<>0 then
begin
ZLO_Close();
FreeLibrary(DllHandle);
end;
ClearServers;
mutex.Free;
servers.Free;
end;

procedure TForm1.ReconnectTimerTimer(Sender: TObject);
begin
ReconnectTimer.Enabled:=false;
memo1.Lines.Add('Reconnecting');
ClearServers();
if ZLO_ConnectMServer('zlofenix.org') then
begin
button1.Enabled:=false;
Memo1.Lines.Add('Connected to master');
ReconnectTimer.Interval:=5000;
end
else
begin
Memo1.Lines.Add('Cant connect to master, will reconnect in 10s');
ReconnectTimer.Enabled:=true;
ReconnectTimer.Interval:=10000;
end;
end;

procedure TForm1.UpdateTimerTimer(Sender: TObject);
begin
UpdateLib;
UpdateTimer.Enabled:=false;
end;

end.
