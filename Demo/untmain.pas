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
  avRes, avTypes, avTess, mutils;

type
  { TfrmMain }

  TfrmMain = class(TForm)
    {$IfDef DCC}
    ApplicationEvents: TApplicationEvents;
    {$EndIf}
    {$IfDef FPC}
    ApplicationProperties: TApplicationProperties;
    {$EndIf}
    procedure ApplicationPropertiesIdle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FMain: TavMainRender;
    FFrameBuffer: TavFrameBuffer;

    FFPSCounter: Integer;
    FFPSMeasureTime: Integer;
  public
    {$IfDef FPC}
    procedure EraseBackground(DC: HDC); override;
    {$EndIf}
    {$IfDef DCC}
    procedure WMEraseBkgnd(var Message: TWmEraseBkgnd); message WM_ERASEBKGND;
    {$EndIf}
    procedure RenderScene;
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
  FMain.Camera.Eye := Vec(-1.6, 1.4,-2.0);
  FMain.Projection.FarPlane := 10.0;
  FMain.Projection.NearPlane := 0.1;

  FFrameBuffer := Create_FrameBufferMultiSampled(FMain, [TTextureFormat.RGBA, TTextureFormat.D32f], 8, [true, false]);
  //FFrameBuffer := Create_FrameBuffer(FMain, [TTextureFormat.RGBA, TTextureFormat.D32f], [true, false]);
end;

procedure TfrmMain.ApplicationPropertiesIdle(Sender: TObject; var Done: Boolean);
begin
  if FMain <> nil then FMain.InvalidateWindow;
  Done := False;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FMain);
end;

procedure TfrmMain.FormPaint(Sender: TObject);
begin
  RenderScene;
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

procedure TfrmMain.RenderScene;
  procedure UpdateFPS;
  var measureTime: Int64;
  begin
    measureTime := FMain.Time64 div 100;
    if measureTime > FFPSMeasureTime then
    begin
      FFPSMeasureTime := measureTime;
      FFPSCounter := 0;
    end
    else
      Inc(FFPSCounter);
  end;

var dt, tn: Single;
begin
  if FMain = nil then Exit;

  UpdateFPS;

  if FMain.Bind then
  try
    FMain.States.DepthTest := True;

    FFrameBuffer.FrameRect := RectI(0, 0, ClientWidth, ClientHeight);
    FFrameBuffer.Select;

    FMain.Clear(Vec(0.0,0.2,0.4,1.0), True, FMain.Projection.DepthRange.y, True);

    FFrameBuffer.BlitToWindow;
    FMain.Present;
  finally
    FMain.Unbind;
  end;
end;

end.

