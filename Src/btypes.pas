unit bTypes;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils, avModel, avMesh,
  avContnrs,
  mutils;

type
  { TbModels }

  TbModels = record
    names  : array of string;
    handles: IavModelInstanceArr;
    procedure Update(const ATransform: TMat4; const APrefabs: IavMeshInstances; const ACollection: TavModelCollection);
  end;

  TbLights = record

  end;

  TbRenderResources = record
    model: TbModels;
    light: TbLights;
  end;

function ResourceModels(const ANames: array of string): TbRenderResources;

implementation

type
  EResourceError = class (Exception);

function ResourceModels(const ANames: array of string): TbRenderResources;
var
  i: Integer;
begin
  SetLength(Result.model.names, Length(ANames));
  for i := 0 to Length(ANames) - 1 do
    Result.model.names[i] := ANames[i];
end;

{ TbModels }

procedure TbModels.Update(const ATransform: TMat4; const APrefabs: IavMeshInstances; const ACollection: TavModelCollection);
var
  i: Integer;
  inst: IavMeshInstance;
begin
  if handles = nil then
  begin
    handles := TavModelInstanceArr.Create();
    handles.Capacity := Length(names);
    for i := 0 to Length(names) - 1 do
    begin
      if not APrefabs.TryGetValue(names[i], inst) then
        raise EResourceError.CreateFmt('Model "%s" not found.', [names[i]]);
      handles.Add( ACollection.ObtainModel(inst.Clone(names[i])) );
    end;
  end;

  for i := 0 to handles.Count - 1 do
    handles[i].Mesh.Transform := ATransform;
end;

end.
