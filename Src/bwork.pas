unit bWork;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Windows,
  Classes, SysUtils, bWorld, avRes, avTypes, mutils,
  avModel, avTexLoader, bFPVCamera, bLights;

type

  { TbLighter }

  TbLighter = class (TbGameObject)
  private
    FLightSources: array of TavPointLight;
  protected
    procedure AfterRegister; override;
  public
  end;

  { TbWork }

  TbWork = class (TavMainRenderChild)
  private
    FWorld: TbWorld;

    FStatic : TbStaticObject;
    FLighter: TbLighter;

    FFPVCamera: TbFPVCamera;

    FLastXY: TVec2i;
  protected
    property World: TbWorld read FWorld;

    procedure EMMouseDown    (var AMsg: TavMouseDownMessage); message EM_MOUSEDOWN;
    procedure EMMouseUp      (var AMsg: TavMouseUpMessage);   message EM_MOUSEUP;
    procedure EMMouseDblClick(var AMsg: TavMouseDblClick);    message EM_MOUSEDBLCLICK;
    procedure EMMouseMove    (var AMsg: TavMouseMessage);     message EM_MOUSEMOVE;
    procedure EMMouseWheel   (var AMsg: TavMouseMessage);     message EM_MOUSEWHEEL;

    procedure EMUps(var AMsg: TavMessage); message EM_UPS;
  public
    procedure Render; virtual;
    procedure AfterConstruction; override;
  end;

implementation

{ TbLighter }

procedure TbLighter.AfterRegister;
begin
  inherited AfterRegister;
  SetLength(FLightSources, 1);
  FLightSources[0] := World.Renderer.CreatePointLight();
  //FLightSources[0].Pos := Vec(14, 10, 0);
  FLightSources[0].Pos := Vec(0, 0, 0);
  FLightSources[0].Radius := 250;
  FLightSources[0].Color := Vec(1,1,1);
  FLightSources[0].CastShadows := True;
end;

{ TbWork }

procedure TbWork.EMMouseDown(var AMsg: TavMouseDownMessage);
begin

end;

procedure TbWork.EMMouseUp(var AMsg: TavMouseUpMessage);
begin

end;

procedure TbWork.EMMouseDblClick(var AMsg: TavMouseDblClick);
begin

end;

procedure TbWork.EMMouseMove(var AMsg: TavMouseMessage);
var newPos: TVec2i;
    delta: TVec2i;
begin
  newPos := Vec(AMsg.xPos, AMsg.yPos);
  if sLeft in AMsg.shifts then
  begin
    delta := FLastXY - newPos;
    FFPVCamera.Yaw := FFPVCamera.Yaw + delta.x * 0.001;
    FFPVCamera.Pitch := FFPVCamera.Pitch - delta.y * 0.001;
  end;
  FLastXY := newPos;
end;

procedure TbWork.EMMouseWheel(var AMsg: TavMouseMessage);
begin

end;

procedure TbWork.EMUps(var AMsg: TavMessage);
begin
  FWorld.UpdateStep;
  if GetKeyState(Ord('R')) < 0 then FWorld.Renderer.InvalidateShaders;
  if GetKeyState(Ord('W')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos + FFPVCamera.Dir * 0.1;
  if GetKeyState(Ord('S')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos - FFPVCamera.Dir * 0.1;
end;

procedure TbWork.Render;
begin
  if Main.Bind then
  try
    FWorld.Renderer.PrepareToDraw;
    FWorld.Renderer.DrawWorld;
    Main.Present;
  finally
    Main.Unbind;
  end;
end;

procedure TbWork.AfterConstruction;
//var
//  i: Integer;
var mv, mp: TMat4;
    mres: TMat4;
begin
  inherited AfterConstruction;

  FWorld := TbWorld.Create(Self);

  FWorld.Renderer.PreloadModels(['assets\sponza\mini.avm']);
  FStatic := TbStaticObject.Create(FWorld);
  FStatic.AddModel('Cube');
  FStatic.AddModel('Arrow');

  //FWorld.Renderer.PreloadModels(['assets\sponza\model.avm']);
  //FStatic := TbStaticObject.Create(FWorld);
  //for i := 0 to 382 do
  //  if i = 2 then
  //    Continue
  //  else
  //    FStatic.AddModel('sponza_'+Format('%.2d', [i]));

  FLighter := TbLighter.Create(FWorld);

  Main.Projection.NearPlane := 1;
  Main.Projection.FarPlane := 10000;

  FFPVCamera := TbFPVCamera.Create(Self);
  FFPVCamera.Pos := Vec(-22, 5, 1);
  FFPVCamera.Yaw := 0.5*Pi;

  FFPVCamera.Pos := Vec(0, 0, 0);
  FFPVCamera.Yaw := FFPVCamera.Yaw + Pi;
//  Main.Projection.Fov := 0.5 * Pi;
//  Main.Projection.Aspect := 1;

//  mv := Main.Camera.Matrix;
//  mp := Main.Projection.Matrix;
//  mres := mv * mp;
//  AllocConsole;
//  Write(ToStr(mres.Row[0]));
end;

end.

