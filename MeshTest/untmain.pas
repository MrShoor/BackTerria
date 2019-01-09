unit untMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  avRes, avTypes, mutils, avCameraController,
  bMesh, bModel;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    procedure ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
  private
    FMain: TavMainRender;
    FFBO : TavFrameBuffer;
    FProgram: TavProgram;

    FModelCollection: TbModelColleciton;

    FModels: IbModelInstanceArr;
    FAnim : IbAnimationController;

    FImportRes: TImportResult;
    FImportedMeshes: IbMeshInstanceNameMap;

    FEvents: IAnimationEventArr;

    function FindMeshes(const ANames: array of string): IbMeshInstanceArr;
  public
    procedure RenderScene;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

const meshIdx = 1;

procedure TfrmMain.FormCreate(Sender: TObject);

  procedure ImportModel;
  var
    i: Integer;
  begin
    FImportRes := bMesh_LoadFromFile('D:\test\out.dat');
    FImportRes.Meshes[meshIdx].ApplyMorphFrameLerp(2);

    FImportedMeshes := TbMeshInstanceNameMap.Create();
    for i := 0 to FImportRes.MeshInstances.Count - 1 do
      FImportedMeshes.Add(FImportRes.MeshInstances[i].Name, FImportRes.MeshInstances[i]);
  end;

begin
  FMain := TavMainRender.Create(nil);
  FFBO := Create_FrameBuffer(FMain, [TTextureFormat.RGBA, TTextureFormat.D32f]);
  FProgram := TavProgram.Create(FMain);
  FProgram.Load('MeshTest', False, 'D:\Projects\BackTerria\MeshTest\shaders\!Out');

  FModelCollection := TbModelColleciton.Create(FMain);

  FMain.Window := Handle;
  FMain.Init3D(apiDX11);

  ImportModel;

  //FModels := FModelCollection.CreateModels(FindMeshes(['arissa:Body_Geo', 'arissa:Cloak_Geo', 'arissa:Eyes', 'arissa:Skirt_Geo', 'arissa:Weapons_Geo']));
  FModels := FModelCollection.CreateModels(FindMeshes(['Stick']));
  FAnim := Create_bAnimationController(FModels);
  FAnim.SetTime(FMain.Time64);
  FModels.AddArray(FModelCollection.CreateModels(FindMeshes(['Cube'])));

  //FAnim.BoneAnimationSequence(['Hunter_Raise0'], True);
  FAnim.BoneAnimationSequence(['StickArmAction'], True);
  FEvents := TAnimationEventArr.Create();

  FMain.Projection.Fov := Pi*0.25;
  FMain.Projection.DepthRange := Vec(1, 0);
  FMain.Projection.NearPlane := 0.01;
  FMain.Projection.FarPlane := 1000;

  FMain.Camera.At := Vec(0,0,0);
  FMain.Camera.Up := Vec(0,1,0);
  FMain.Camera.Eye := Vec(-5, 5, -5);

  with TavCameraController.Create(FMain) do
  begin
    CanRotate := True;
  end;
end;

procedure TfrmMain.ApplicationProperties1Idle(Sender: TObject; var Done: Boolean);
begin
  Done := False;
  FMain.InvalidateWindow;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FMain);
end;

procedure TfrmMain.FormPaint(Sender: TObject);
begin
  RenderScene;
end;

function TfrmMain.FindMeshes(const ANames: array of string): IbMeshInstanceArr;
var
  i: Integer;
begin
  Result := TbMeshInstanceArr.Create();
  for i := 0 to Length(ANames) - 1 do
    Result.Add(FImportedMeshes[ANames[i]]);
end;

procedure TfrmMain.RenderScene;
var
  i: Integer;
begin
  Caption := FormatFloat('0.00', Len(FMain.Camera.Eye));

  if FMain.Bind then
  try
    FEvents.Clear();
    FAnim.SetTime(FMain.Time64, FEvents);
    for i := 0 to FEvents.Count - 1 do
    begin
      WriteLn(FEvents[i].Animation, ': ', FEvents[i].Marker, ' ', TimeToStr(now()));
    end;
//    WriteLn('------');

    //FImportRes.Meshes[meshIdx].ApplyMorphFrameLerp(FMain.Time64 / 1000);
    //FVB.Invalidate;

    FMain.States.DepthTest := True;
    FMain.States.DepthFunc := cfGreater;

    FFBO.FrameRect := RectI(Vec(0,0), FMain.WindowSize);
    FFBO.Select();
    FFBO.Clear(0, Black);
    FFBO.ClearDS(0);

    FModelCollection.SubmitBufferClear();
    FModelCollection.SubmitToDraw(FModels);

    FProgram.Select();
    FModelCollection.Draw();

    FFBO.BlitToWindow();
    FMain.Present;
  finally
    FMain.Unbind;
  end;
end;

end.

