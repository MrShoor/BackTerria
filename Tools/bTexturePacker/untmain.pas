unit untMain;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Windows,
  Classes, SysUtils, avTypes, avMesh, avContnrs, untJobs, Imaging, ImagingTypes, ImagingUtility, mutils;

type
  TCopyFrom = packed record
    exists    : Boolean;
    srctex    : TImageData;
    srcchannel: Integer;
    srccol    : Byte;
  end;

  TNewTexture = packed record
    srcfilename: string;
    dstfilename: string;
    copyfrom: array [0..3] of TCopyFrom;
  end;

  { TCallBackHandler }

  TCallBackHandler = class(TInterfacedObject, IMeshLoaderCallback)
  private type
    ITexRemap = {$IfDef FPC}specialize{$EndIf}IHashMap<string, string>;
    TTexRemap = {$IfDef FPC}specialize{$EndIf}THashMap<string, string>;
  private
    FJob: IJob;
    FDestDir: string;

    FCurrentMesh: string;
    FCurrentMeshTexSizeX: Integer;
    FCurrentMeshTexSizeY: Integer;
    FCurrentMaterial: TMeshMaterial;

    FNewTextures: array [TMeshMaterialTextureKind] of TNewTexture;

    FTexRemap: ITexRemap;

    procedure WriteAllNewTextures();
    procedure WriteTexRemap();
    function GetColorFromRule(const ARule: TRule_CopyChannel): Byte;

    function Hook_TextureFilename(const ATextureFilename: string): string;

    procedure OnLoadingMesh(const AMesh: string);
    procedure OnLoadingMaterial(const AMaterial: TMeshMaterial);
    procedure OnLoadingTexture(const AKind: TMeshMaterialTextureKind; const AFileName: string; const ASize: TVec2i; const AFactor: Single);
  public
    constructor Create(const AJob: IJob);
    destructor Destroy; override;
  end;

procedure DoWork(); overload;
procedure DoWork(const AJobsFile: string); overload;

implementation

procedure DoWork();
begin
  if ParamCount < 1 then
  begin
    WriteLn('Job file required as first param');
    Exit;
  end;
  if not FileExists(ParamStr(1)) then
  begin
    WriteLn('File not exists: "' + ParamStr(1) + '"');
    Exit;
  end;
  DoWork(ParamStr(1));
end;

procedure DoWork(const AJobsFile: string);
var handler: IMeshLoaderCallback;
    jobs: IJobArr;
    i: Integer;
begin
  jobs := ParseJobs('pack_rules.json');

  for i := 0 to jobs.Count - 1 do
  begin
    if not FileExists(jobs[i].SrcFile) then
    begin
      WriteLn('WARNING! File "' + jobs[i].SrcFile + '" not found');
      Continue;
    end;
    WriteLn('Job: "' + jobs[i].SrcFile + '" to "' + jobs[i].DstFile + '"');

    handler := TCallBackHandler.Create(jobs[i]);
    ForceDirectories(ExtractFileDir(jobs[i].DstFile));
    LoadInstancesFromFile(jobs[i].SrcFile, nil, handler);
    CopyFileW(PWideChar(WideString(jobs[i].SrcFile)), PWideChar(WideString(jobs[i].DstFile)), False);
  end;
end;

{ TCallBackHandler }

procedure TCallBackHandler.WriteAllNewTextures();
var tk: TMeshMaterialTextureKind;
    newTexSize: TVec2i;
    newTex: TImageData;
    pDstCol: PByte;
    pSrcCol: PByte;
    i, y, x: Integer;
begin
  for tk := Low(TMeshMaterialTextureKind) to High(TMeshMaterialTextureKind) do
  begin
    if FNewTextures[tk].dstfilename = '' then Continue;
    if FNewTextures[tk].srcfilename <> '' then
    begin
      if FCurrentMeshTexSizeX > 0 then
      begin
        ZeroClear(newTex, SizeOf(newTex));
        if not LoadImageFromFile(FNewTextures[tk].srcfilename, newTex) then
          RaiseImaging('Can''t load: "'+FNewTextures[tk].srcfilename+'"');
        ResizeImage(newTex, FCurrentMeshTexSizeX, FCurrentMeshTexSizeY, rfLanczos);
        SaveImageToFile(FNewTextures[tk].dstfilename, newTex);
        FreeImage(newTex);
      end
      else
        CopyFileW(PWideChar(WideString(FNewTextures[tk].srcfilename)), PWideChar(WideString(FNewTextures[tk].dstfilename)), False);
      Continue;
    end;

    newTexSize := Vec(-1, -1);
    for i := 0 to 3 do
    begin
      if FNewTextures[tk].copyfrom[i].exists then
        newTexSize := Max(newTexSize, Vec(FNewTextures[tk].copyfrom[i].srctex.Width, FNewTextures[tk].copyfrom[i].srctex.Height));
    end;
    if newTexSize.x <= 0 then
      Continue;

    if FCurrentMeshTexSizeX > 0 then
      newTexSize := Vec(FCurrentMeshTexSizeX, FCurrentMeshTexSizeY);

    for i := 0 to 3 do
    begin
      if FNewTextures[tk].copyfrom[i].exists then
      begin
        if FNewTextures[tk].copyfrom[i].srctex.Size > 0 then
          ResizeImage(FNewTextures[tk].copyfrom[i].srctex, newTexSize.x, newTexSize.y, rfLanczos);
      end;
    end;

    ZeroClear(newTex, SizeOf(newTex));
    NewImage(newTexSize.x, newTexSize.y, TImageFormat.ifA8R8G8B8, newTex);

    pDstCol := PByte(newTex.Bits);
    for y := 0 to newTex.Height - 1 do
      for x := 0 to newTex.Width - 1 do
        for i := 0 to 3 do
        begin
          if FNewTextures[tk].copyfrom[i].exists then
          begin
            if FNewTextures[tk].copyfrom[i].srctex.Size > 0 then
            begin
              pSrcCol := PByte(FNewTextures[tk].copyfrom[i].srctex.Bits);
              Inc(pSrcCol, (y*newTex.Width + x)*4 + FNewTextures[tk].copyfrom[i].srcchannel);
              pDstCol^ := pSrcCol^;
            end
            else
            begin
              pDstCol^ := FNewTextures[tk].copyfrom[i].srccol;
            end;
          end;
          Inc(pDstCol);
        end;

    if not SaveImageToFile(FNewTextures[tk].dstfilename, newTex) then
      RaiseImaging('Can''t save: "'+FNewTextures[tk].dstfilename+'"');
    FreeImage(newTex);

    FNewTextures[tk].srcfilename := '';
    FNewTextures[tk].dstfilename := '';
  end;

  for tk := Low(TMeshMaterialTextureKind) to High(TMeshMaterialTextureKind) do
    for i := 0 to 3 do
      FreeImage(FNewTextures[tk].copyfrom[i].srctex);
  ZeroClear(FNewTextures, SizeOf(FNewTextures));
end;

procedure TCallBackHandler.WriteTexRemap();
var fs: TFileStream;
    n: Integer;
    mapFrom, mapTo: string;
begin
  fs := TFileStream.Create(FJob.DstFile+'.texremap', fmCreate);
  try
    n := FTexRemap.Count;
    fs.WriteBuffer(n, SizeOf(n));

    FTexRemap.Reset;
    while FTexRemap.Next(mapFrom, mapTo) do
    begin
      StreamWriteString(fs, mapFrom);
      StreamWriteString(fs, mapTo);
    end;
  finally
    FreeAndNil(fs);
  end;
end;

function TCallBackHandler.GetColorFromRule(const ARule: TRule_CopyChannel): Byte;
begin
  if ARule.SrcColorStr = '' then Exit(ARule.SrcColor);
  if ARule.SrcColorStr = 'matSpec' then
    Exit(Clamp( Round( FCurrentMaterial.matSpec.f[ARule.SrcChannel] * 255 ), 0, 255));
  if ARule.SrcColorStr = 'matDiff' then
    Exit(Clamp( Round( FCurrentMaterial.matDiff.f[ARule.SrcChannel] * 255 ), 0, 255));
  if ARule.SrcColorStr = 'matSpecHardness' then
    Exit(Clamp( Round( FCurrentMaterial.matSpecHardness * 255 ), 0, 255));
  if ARule.SrcColorStr = 'matEmitFactor' then
    Exit(Clamp( Round( FCurrentMaterial.matEmitFactor * 255 ), 0, 255));
  if ARule.SrcColorStr = 'matSpecIOR' then
    Exit(Clamp( Round( FCurrentMaterial.matSpecIOR * 255 ), 0, 255));
  Result := 0;
end;

function TCallBackHandler.Hook_TextureFilename(const ATextureFilename: string): string;
begin
  Result := ATextureFilename;
end;

procedure TCallBackHandler.OnLoadingMesh(const AMesh: string);
var rule: TRule_Resize;
begin
  WriteAllNewTextures();

  FCurrentMesh := AMesh;
  if FJob.Rules_Resize.TryGetValue(AMesh, rule) then
  begin
    FCurrentMeshTexSizeX := rule.TexSizeX;
    FCurrentMeshTexSizeY := rule.TexSizeY;
  end
  else
  begin
    FCurrentMeshTexSizeX := -1;
    FCurrentMeshTexSizeY := -1;
  end;
  WriteLn('    Processing mesh: "' + AMesh + '"');
end;

procedure TCallBackHandler.OnLoadingMaterial(const AMaterial: TMeshMaterial);
begin
  FCurrentMaterial := AMaterial;
end;

procedure TCallBackHandler.OnLoadingTexture(
  const AKind: TMeshMaterialTextureKind; const AFileName: string;
  const ASize: TVec2i; const AFactor: Single);
var rules: IRule_CopyChannelArr;
  rule: PRule_CopyChannel;
  inRules: Boolean;
  i: Integer;
  pSrcImg: PImageData;
  dstLocalName: string;
begin
  inRules := False;
  rules := FJob.Rules_CopyChannel;
  for i := 0 to rules.Count - 1 do
  begin
    rule := PRule_CopyChannel(rules.PItem[i]);
    if rule^.Src = AKind then
    begin
      inRules := True;
      dstLocalName := FCurrentMesh + '_' + GetMaterialTextureKindName(rule^.Dst) + '.png';
      FTexRemap.AddOrSet(AFileName, dstLocalName);
      if FNewTextures[rule^.Dst].dstfilename = '' then
        FNewTextures[rule^.Dst].dstfilename := FDestDir + '\' + dstLocalName;

      Assert(not FNewTextures[rule^.Dst].copyfrom[rule^.DstChannel].exists);
      FNewTextures[rule^.Dst].copyfrom[rule^.DstChannel].exists := True;

      if AFileName = '' then
      begin
        FNewTextures[rule^.Dst].copyfrom[rule^.DstChannel].srccol := GetColorFromRule(rule^);
      end
      else
      begin
        pSrcImg := @FNewTextures[rule^.Dst].copyfrom[rule^.DstChannel].srctex;
        LoadImageFromFile(AFileName, pSrcImg^);
        if pSrcImg^.Format <> TImageFormat.ifA8R8G8B8 then
          ConvertImage(pSrcImg^, TImageFormat.ifA8R8G8B8);
      end;
    end;
  end;

  if not inRules then
  begin
    if AFileName <> '' then
    begin
      FNewTextures[AKind].srcfilename := ExpandFileName(AFileName);
      FNewTextures[AKind].dstfilename := FDestDir + '\' + AFileName;
    end;
  end;
end;

constructor TCallBackHandler.Create(const AJob: IJob);
begin
  FJob := AJob;
  FDestDir := ExtractFileDir(AJob.DstFile);
  FTexRemap := TTexRemap.Create();
end;

destructor TCallBackHandler.Destroy;
begin
  WriteAllNewTextures();
  WriteTexRemap();
  inherited Destroy;
end;

end.

