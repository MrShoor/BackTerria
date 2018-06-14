unit bWork;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Windows,
  Classes, SysUtils, bWorld, avRes, avTypes, mutils,
  avContnrs, avModel, avMesh,
  bLevel, bTypes, bFPVCamera;

type

  { TbWork }

  TbWork = class (TavMainRenderChild)
  private
    FWorld: TbWorld;
    FGBuffer: TavFrameBuffer;
    FFrameBuffer: TavFrameBuffer;

    FPostProcess: TavProgram;

    FAllMeshes: IavMeshInstances;

    FModelsProgram: TavProgram;
    FModels: TavModelCollection;

    FStatic: TbGameObject;
    FFPVCamera: TbFPVCamera;

    FLastXY: TVec2i;

    FHammerslayPts: TVec4Arr;
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

const
  SHADERS_LOAD_FROMRES = False;
  SHADERS_DIR = 'D:/Projects/BackTerria/Src/shaders/!Out';

  Sampler_Depth : TSamplerInfo = (
    MinFilter  : tfNearest;
    MagFilter  : tfNearest;
    MipFilter  : tfNone;
    Anisotropy : 0;
    Wrap_X     : twClamp;
    Wrap_Y     : twClamp;
    Wrap_Z     : twClamp;
    Border     : (x: 1; y: 1; z: 1; w: 1);
  );

//{$R '../Src/Shaders/shaders.rc'}

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
  if GetKeyState(Ord('R')) < 0 then
  begin
    FModelsProgram.Invalidate;
    FPostProcess.Invalidate;
  end;
  if GetKeyState(Ord('W')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos + FFPVCamera.Dir * 0.1;
  if GetKeyState(Ord('S')) < 0 then FFPVCamera.Pos := FFPVCamera.Pos - FFPVCamera.Dir * 0.1;

end;

procedure TbWork.Render;
begin
  if Main.Bind then
  try
    Main.States.DepthTest := True;

    FGBuffer.FrameRect := RectI(Vec(0, 0), Main.WindowSize);
    FGBuffer.Select;

    Main.Clear(Vec(0.0,0.2,0.4,1.0), True, Main.Projection.DepthRange.y, True);

    FStatic.Resource.model.Update(IdentityMat4, FAllMeshes, FModels);

    FModelsProgram.Select();
    FModels.Select;
    FModels.Draw(FStatic.Resource.model.handles);


    FFrameBuffer.FrameRect := RectI(Vec(0, 0), Main.WindowSize);
    FFrameBuffer.Select;

    FPostProcess.Select();
    FPostProcess.SetUniform('uHammerslayPts', FHammerslayPts);
    FPostProcess.SetUniform('Color', FGBuffer.GetColor(0), Sampler_NoFilter);
    FPostProcess.SetUniform('Normals', FGBuffer.GetColor(1), Sampler_NoFilter);
    FPostProcess.SetUniform('Depth', FGBuffer.GetDepth, Sampler_Depth);
    FPostProcess.Draw(ptTriangleStrip, cmNone, False, 0, 0, 4);

    FFrameBuffer.BlitToWindow;
    Main.Present;
  finally
    Main.Unbind;
  end;
end;

procedure TbWork.AfterConstruction;

  function PreloadMeshes(const AFileName: string): IavMeshInstances;
  var name: string;
      inst: IavMeshInstance;
  begin
    Result := LoadInstancesFromFile(AFileName);
    Result.Reset;
    while Result.Next(name, inst) do
      FAllMeshes.Add(name, inst);
  end;

var
  meshes: IavMeshInstances;
  meshname: string;
  names : array of string;
  i: Integer;
begin
  inherited AfterConstruction;

  FHammerslayPts := GenerateHammersleyPts(32);

  FAllMeshes := TavMeshInstances.Create();
  FModels := TavModelCollection.Create(Self);
  FModelsProgram := TavProgram.Create(Self);
  FModelsProgram.Load('avMesh', SHADERS_LOAD_FROMRES, SHADERS_DIR);

  FPostProcess := TavProgram.Create(Self);
  FPostProcess.Load('PostProcess1', SHADERS_LOAD_FROMRES, SHADERS_DIR);

  meshes := PreloadMeshes('assets\sponza\model.avm');
  SetLength(names, meshes.Count);
  i := 0;
  meshes.Reset;
  while meshes.NextKey(meshname) do
  begin
    names[i] := meshname;
    Inc(i);
  end;

  FWorld := TbWorld.Create(Self);

  FStatic := TbGameObject.Create(FWorld);
  FStatic.Resource := ResourceModels(names);

  //FGBuffer := Create_FrameBufferMultiSampled(Main, [TTextureFormat.RGBA, TTextureFormat.D32f], 8, [true, false]);
  FGBuffer := Create_FrameBuffer(Main, [TTextureFormat.RGBA, TTextureFormat.RGBA, TTextureFormat.D32f], [true, false, false]);
  FFrameBuffer := Create_FrameBuffer(Main, [TTextureFormat.RGBA], [true]);

  Main.Projection.NearPlane := 1;
  Main.Projection.FarPlane := 10000;

  FFPVCamera := TbFPVCamera.Create(Self);
  FFPVCamera.Pos := Vec(-22, 5, 1);
  FFPVCamera.Yaw := 0.5*Pi;
end;

end.

