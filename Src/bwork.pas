unit bWork;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, bWorld, avRes, avTypes, mutils,
  avContnrs, avModel, avMesh,
  bLevel, bTypes;

type

  { TbWork }

  TbWork = class (TavMainRenderChild)
  private
    FWorld: TbWorld;
    FFrameBuffer: TavFrameBuffer;

    FAllMeshes: IavMeshInstances;

    FModelsProgram: TavProgram;
    FModels: TavModelCollection;

    FStatic: TbGameObject;
  protected
    property World: TbWorld read FWorld;

    procedure EMUps(var AMsg: TavMessage); message EM_UPS;
  public
    procedure Render; virtual;
    procedure AfterConstruction; override;
  end;

implementation

const
  SHADERS_LOAD_FROMRES = False;
  SHADERS_DIR = 'D:/Projects/BackTerria/Src/shaders/!Out';
//{$R '../Src/Shaders/shaders.rc'}

{ TbWork }

procedure TbWork.EMUps(var AMsg: TavMessage);
begin
  FWorld.UpdateStep;
end;

procedure TbWork.Render;
begin
  if Main.Bind then
  try
    Main.States.DepthTest := True;

    FFrameBuffer.FrameRect := RectI(Vec(0, 0), Main.WindowSize);
    FFrameBuffer.Select;

    Main.Clear(Vec(0.0,0.2,0.4,1.0), True, Main.Projection.DepthRange.y, True);

    FStatic.Resource.model.Update(IdentityMat4, FAllMeshes, FModels);

    FModelsProgram.Select();
    FModels.Select;
    FModels.Draw(FStatic.Resource.model.handles);

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

  FAllMeshes := TavMeshInstances.Create();
  FModels := TavModelCollection.Create(Self);
  FModelsProgram := TavProgram.Create(Self);
  FModelsProgram.Load('avMesh', SHADERS_LOAD_FROMRES, SHADERS_DIR);

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

  FFrameBuffer := Create_FrameBufferMultiSampled(Main, [TTextureFormat.RGBA, TTextureFormat.D32f], 8, [true, false]);
end;

end.

