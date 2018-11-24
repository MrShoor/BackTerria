unit untJobs;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, avTypes, avContnrs, avMesh, superobject;

type
  TRule_Resize = record
    MeshName : string;
    TexSizeX : Integer;
    TexSizeY : Integer;
  end;
  IRule_ResizeMap = {$IfDef FPC}specialize{$EndIf}IHashMap<string, TRule_Resize>;
  TRule_ResizeMap = {$IfDef FPC}specialize{$EndIf}THashMap<string, TRule_Resize>;

  TRule_CopyChannel = packed record
    Src: TMeshMaterialTextureKind;
    SrcChannel: Integer;
    SrcColorStr: string;
    SrcColor: Byte;
    DstFormat: string;
    Dst: TMeshMaterialTextureKind;
    DstChannel: Integer;
  end;
  PRule_CopyChannel = ^TRule_CopyChannel;
  IRule_CopyChannelArr = {$IfDef FPC}specialize{$EndIf}IArray<TRule_CopyChannel>;
  TRule_CopyChannelArr = {$IfDef FPC}specialize{$EndIf}TArray<TRule_CopyChannel>;

  IJob = interface
    function SrcFile: string;
    function DstFile: string;

    function Rules_Resize: IRule_ResizeMap;
    function Rules_CopyChannel: IRule_CopyChannelArr;
  end;
  IJobArr = {$IfDef FPC}specialize{$EndIf}IArray<IJob>;
  TJobArr = {$IfDef FPC}specialize{$EndIf}TArray<IJob>;

function ParseJobs(const AFileName: string): IJobArr; overload;
function ParseJobs(const ASO: ISuperObject): IJobArr; overload;

implementation

type
  EJsonParseException = class (Exception)
  end;

  { TJob }

  TJob = class(TInterfacedObject, IJob)
  private
    FSrcFile: string;
    FDstFile: string;
    FRules_Resize: IRule_ResizeMap;
    FRules_CopyChannel: IRule_CopyChannelArr;
  public
    function SrcFile: string;
    function DstFile: string;

    function Rules_Resize: IRule_ResizeMap;
    function Rules_CopyChannel: IRule_CopyChannelArr;

    constructor Create(const ASO: ISuperObject);
  end;

procedure RaiseError(msg: string);
begin
  raise EJsonParseException.Create(msg);
end;

function ParseJobs(const AFileName: string): IJobArr;
var sobj: ISuperObject;
begin
  sobj := TSuperObject.ParseFile(AFileName, False);
  Result := ParseJobs(sobj);
end;

function ParseJobs(const ASO: ISuperObject): IJobArr;
var sarr: TSuperArray;
    i: Integer;
begin
  if ASO.O['Jobs'] = nil then RaiseError('"Jobs" not found');
  if not ASO.O['Jobs'].IsType(stArray) then RaiseError('"Jobs" is not array');
  sarr := ASO.O['Jobs'].AsArray;
  Result := TJobArr.Create();
  for i := 0 to sarr.Length - 1 do
    Result.Add(TJob.Create(sarr.O[i]));
end;

{ TJob }

function TJob.SrcFile: string;
begin
  Result := FSrcFile;
end;

function TJob.DstFile: string;
begin
  Result := FDstFile;
end;

function TJob.Rules_Resize: IRule_ResizeMap;
begin
  Result := FRules_Resize;
end;

function TJob.Rules_CopyChannel: IRule_CopyChannelArr;
begin
  Result := FRules_CopyChannel;
end;

constructor TJob.Create(const ASO: ISuperObject);

  function StrToTextureKind(const AStr: string): TMeshMaterialTextureKind;
  var tk: TMeshMaterialTextureKind;
  begin
    for tk := Low(TMeshMaterialTextureKind) to High(TMeshMaterialTextureKind) do
      if AStr = GetMaterialTextureKindName(tk) then
        Exit(tk);
    RaiseError('Wrong texture kind: "' + AStr + '"');
    Result := TMeshMaterialTextureKind.texkDiffuse_Alpha;
  end;

var sarr: TSuperArray;
    i: Integer;
    new_Resize: TRule_Resize;
    new_Channel: TRule_CopyChannel;
begin
  FRules_Resize := TRule_ResizeMap.Create();
  FRules_CopyChannel := TRule_CopyChannelArr.Create();

  FSrcFile := ExpandFileName( string(ASO.S['Src']) );
  FDstFile := ExpandFileName( string(ASO.S['Dst']) );
  if ASO.O['Resize'] <> nil then
  begin
    if not ASO.O['Resize'].IsType(stArray) then RaiseError('"Resize" is not array');
    sarr := ASO.O['Resize'].AsArray;
    for i := 0 to sarr.Length - 1 do
    begin
      new_Resize.MeshName := string(sarr.O[i].S['MeshName']);
      new_Resize.TexSizeX := sarr.O[i].I['TexSizeX'];
      new_Resize.TexSizeY := sarr.O[i].I['TexSizeY'];
      FRules_Resize.Add(new_Resize.MeshName, new_Resize);
    end;
  end;

  if ASO.O['CopyChannel'] <> nil then
  begin
    if not ASO.O['CopyChannel'].IsType(stArray) then RaiseError('"CopyChannel" is not array');
    sarr := ASO.O['CopyChannel'].AsArray;
    for i := 0 to sarr.Length - 1 do
    begin
      new_Channel.Src := StrToTextureKind(string(sarr.O[i].S['Src']));
      new_Channel.Dst := StrToTextureKind(string(sarr.O[i].S['Dst']));
      new_Channel.SrcChannel := sarr.O[i].I['SrcChannel'];
      new_Channel.DstChannel := sarr.O[i].I['DstChannel'];
      if sarr.O[i].O['SrcColor'].IsType(stString) then
      begin
        new_Channel.SrcColorStr := string(sarr.O[i].S['SrcColor']);
        new_Channel.SrcColor := 0;
      end
      else
      begin
        new_Channel.SrcColorStr := '';
        new_Channel.SrcColor := sarr.O[i].I['SrcColor'];
      end;
      FRules_CopyChannel.Add(new_Channel);
    end;
  end;
end;

end.

