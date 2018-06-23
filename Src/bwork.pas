unit bWork;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Windows,
  Classes, SysUtils, bWorld, avRes, avTypes, mutils,
  avModel, avTexLoader, bFPVCamera, bLights, bUtils;

type
  { TbLighter }

  TbLighter = class (TbGameObject)
  private
    FLightSources: array of IavPointLight;
    FModelSphere: IavModelInstance;
  protected
    procedure SetPos(const AValue: TVec3); override;
    procedure AfterRegister; override;
  public
    procedure WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType = mtDefault); override;
  end;

  { TbAnimatedLighter }

  TbAnimatedLighter = class (TbStaticObject)
  private
    FLight: IavPointLight;
    FModelSphere: IavModelInstance;
    FRoute: array of TVec3;
    FRoutePos: TPathPos;
    FRouteSpeed: Single;

    //FModels.AddArray( World.Renderer.CreateModelInstances([AName]) );
    //FModels.Last.Mesh.Transform := IdentityMat4;

  protected
    procedure SetPos(const AValue: TVec3); override;
    procedure UpdateStep; override;
  public
    procedure WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType = mtDefault); override;
  protected
    procedure AfterRegister; override;
  end;

  { TbWork }

  TbWork = class (TavMainRenderChild)
  private
    FWorld: TbWorld;

    FStatic : TbStaticObject;
    FLighter: TbLighter;
    FAnimatedLighter: TbAnimatedLighter;

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

{ TbAnimatedLighter }

procedure TbAnimatedLighter.AfterRegister;
begin
  inherited AfterRegister;
  FLight := World.Renderer.CreatePointLight();
  FLight.Radius := 30;
  FLight.Color := Vec(1,1,1);
  FLight.CastShadows := True;

  SetLength(FRoute, 5);
  FRoute[0] := Vec(33.68775, 6.74312, -13.63531);
  FRoute[1] := Vec(-37.58761, 6.45068, -12.0576);
  FRoute[2] := Vec(-37.58761, 5.93924, 13.51868);
  FRoute[3] := Vec(35.11256, 6.84062, 13.53033);
  FRoute[4] := FRoute[0];

//  FRoute[0] := Vec(7,7,7);

  Pos := FRoute[0];

  FRoutePos.Idx := 0;
  FRoutePos.Pos := 0;
  FRouteSpeed := 0.1;

  FModelSphere := World.Renderer.CreateModelInstances(['light_source']).Item[0];

  SubscribeForUpdateStep;
end;

procedure TbAnimatedLighter.SetPos(const AValue: TVec3);
begin
  inherited;
  if Assigned(FLight) then
    FLight.Pos := Pos;
  if Assigned(FModelSphere) then
    FModelSphere.Mesh.Transform := Transform();
end;

procedure TbAnimatedLighter.UpdateStep;
var pathDir: TVec3;
    p: TVec3;
    a: Single;
begin
  inherited UpdateStep;
  p := TravelByPath(FRoute, FRouteSpeed, FRoutePos);
  pathDir := FRoute[FRoutePos.Idx+1] - FRoute[FRoutePos.Idx];
  pathDir := normalize( Quat(Vec(0,1,0), 0.5*Pi) * pathDir );

  a := sin(FRoutePos.Pos * Pi)*3;
  p := p + pathDir * a * sin(FRoutePos.Pos*15);

  Pos := p;
end;

procedure TbAnimatedLighter.WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType);
begin
  if AType <> mtEmissive then Exit;
  ACollection.Add(FModelSphere);
end;

{ TbLighter }

procedure TbLighter.AfterRegister;
begin
  inherited AfterRegister;
  SetLength(FLightSources, 1);
  FLightSources[0] := World.Renderer.CreatePointLight();
//  FLightSources[0].Pos := Vec(14, 10, 0);
//  FLightSources[0].Pos := Vec(0, 0, 0);
  FLightSources[0].Radius := 230;
  FLightSources[0].Color := Vec(1,1,1);
  FLightSources[0].CastShadows := True;

  Pos := Vec(14, 10, 0);

  FModelSphere := World.Renderer.CreateModelInstances(['light_source']).Item[0];
end;

procedure TbLighter.SetPos(const AValue: TVec3);
var i: Integer;
begin
  inherited;
  for i := 0 to Length(FLightSources) - 1 do
    if Assigned(FLightSources[i]) then
      FLightSources[i].Pos := Pos;
end;

procedure TbLighter.WriteModels(const ACollection: IavModelInstanceArr; AType: TModelType);
begin
  if AType <> mtEmissive then Exit;
  FModelSphere.Mesh.Transform := Transform();
  ACollection.Add(FModelSphere);
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
  if not (GetActiveWindow = Main.Window) then Exit;
  if GetKeyState(Ord('R')) < 0 then FWorld.Renderer.InvalidateShaders;
  if GetKeyState(Ord('W')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos + FFPVCamera.Dir * 0.1;
  if GetKeyState(Ord('S')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos - FFPVCamera.Dir * 0.1;
  if GetKeyState(Ord('L')) < 0 then
  begin
    FFPVCamera.Pos := FAnimatedLighter.Pos;
    FFPVCamera.Yaw := -0.5*Pi;
  end;
  if GetKeyState(Ord('P')) < 0 then
    FreeAndNil(FLighter);
end;

procedure TbWork.Render;
begin
  if Main.Bind then
  try
    Main.States.DepthTest := True;
    Main.States.DepthWrite := True;
    Main.States.DepthFunc := cfGreater;
    Main.Projection.DepthRange := Vec(1,0);

    FWorld.Renderer.PrepareToDraw;
    Main.Clear(Vec(0,0,0,0), true, Main.Projection.DepthRange.y, true);
    FWorld.Renderer.DrawWorld;
    Main.Present;
  finally
    Main.Unbind;
  end;
end;

procedure TbWork.AfterConstruction;
var
  i: Integer;
begin
  inherited AfterConstruction;

  FWorld := TbWorld.Create(Self);

//  FWorld.Renderer.PreloadModels(['assets\sponza\mini.avm']);
//  FStatic := TbStaticObject.Create(FWorld);
//  FStatic.AddModel('Cube');
//  FStatic.AddModel('Arrow');

  FWorld.Renderer.PreloadModels(['assets\sponza\model.avm']);
  FStatic := TbStaticObject.Create(FWorld);
  for i := 0 to 382 do
    if i = 2 then
      Continue
    else
      FStatic.AddModel('sponza_'+Format('%.2d', [i]));

  FLighter := TbLighter.Create(FWorld);

  FAnimatedLighter := TbAnimatedLighter.Create(FWorld);

  Main.Projection.NearPlane := 1;
  Main.Projection.FarPlane := 200;

  FFPVCamera := TbFPVCamera.Create(Self);
  FFPVCamera.Pos := Vec(-22, 5, 1);
  FFPVCamera.Yaw := 0.5*Pi;

//  FFPVCamera.Pos := Vec(0, 0, 0);
//  FFPVCamera.Yaw := FFPVCamera.Yaw + Pi;
end;

end.

