unit untmain;
{$I avConfig.inc}

interface

uses
  {$IfDef FPC}
  LCLType,
  FileUtil,
  {$Else}
  Windows,
  Messages,
  AppEvnts,
  {$EndIf}
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  bWork,
  avRes, avTypes, avTess, mutils;

type
  { TfrmMain }

  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FMain: TavMainRender;
    FWork: TbWork;

    FFPSCounter: Integer;
    FFPSMeasureTime: Integer;

    procedure Idle(Sender: TObject; var Done: Boolean);
  public
    {$IfDef FPC}
    procedure EraseBackground(DC: HDC); override;
    {$EndIf}
    {$IfDef DCC}
    procedure WMEraseBkgnd(var Message: TWmEraseBkgnd); message WM_ERASEBKGND;
    {$EndIf}
  end;

var
  frmMain: TfrmMain;

implementation

{$IfnDef notDCC}
  {$R *.dfm}
{$EndIf}

{$IfDef FPC}
  {$R *.lfm}
{$EndIf}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  FMain := TavMainRender.Create(Nil);
  FMain.Window := Handle;
  FMain.Init3D(apiDX11);
  FMain.Projection.DepthRange := Vec(1, 0);
  FMain.States.DepthFunc := cfGreater;

  FWork := TbWork.Create(FMain);

  FMain.UpdateStatesInterval := 8;

  Application.OnIdle := {$IfDef FPC}@{$EndIf}Idle;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FMain);
end;

procedure TfrmMain.FormPaint(Sender: TObject);

  procedure UpdateFPS;
  var measureTime: Int64;
  begin
    measureTime := FMain.Time64 div 100;
    if measureTime > FFPSMeasureTime then
    begin
      FFPSMeasureTime := measureTime;
      Caption := 'FPS:' + IntToStr(FFPSCounter*10 + Random(10));
      FFPSCounter := 0;
    end
    else
      Inc(FFPSCounter);
  end;

begin
  if FMain = nil then Exit;
  if FWork = nil then Exit;

  UpdateFPS;

  FWork.Render;
end;

procedure TfrmMain.Idle(Sender: TObject; var Done: Boolean);
begin
  FMain.InvalidateWindow;
  Done := False;
end;

{$IfDef FPC}
procedure TfrmMain.EraseBackground(DC: HDC);
begin
  //inherited EraseBackground(DC);
end;
{$EndIf}
{$IfDef DCC}
procedure TfrmMain.WMEraseBkgnd(var Message: TWmEraseBkgnd);
begin
  Message.Result := 1;
end;
{$EndIf}

end.

