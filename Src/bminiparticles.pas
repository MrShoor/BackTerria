unit bMiniParticles;

{$IfDef FPC}
  {$mode objfpc}{$H+}
  {$ModeSwitch advancedrecords}
{$EndIf}

interface

uses
  Classes, SysUtils,
  avTypes, avContnrs, avRes, avTess, mutils;

type

  { TParticleVertex }

  TParticleVertex = packed record
    Pos : TVec3;
    Dir : TVec4;
    Size: TVec2;
    ColMult : TVec4;
    ColAdd  : TVec4;
    TexRect : TVec4;
    class function Layout(): IDataLayout; static;
  end;
  PParticleVertex = ^TParticleVertex;
  IParticleVertexArr = {$IfDef FPC}specialize{$EndIf} IArray<TParticleVertex>;
  TParticleVertexArr = {$IfDef FPC}specialize{$EndIf} TVerticesRec<TParticleVertex>;

  { IParticlesHandle }

  IParticlesHandle = interface
    function GetTransform: TMat4;
    function GetWeight: Single;
    procedure SetTransform(const AValue: TMat4);
    procedure SetWeight(const AValue: Single);

    function  Vertices: IParticleVertexArr;
    procedure Invalidate;

    property  Transform: TMat4 read GetTransform write SetTransform;
    property  Weight: Single read GetWeight write SetWeight;
  end;
  IParticlesHandleArr = {$IfDef FPC}specialize{$EndIf} IArray<IParticlesHandle>;
  TParticlesHandleArr = {$IfDef FPC}specialize{$EndIf} TArray<IParticlesHandle>;

  { TbParticleSystem }

  TbParticleSystem = class (TavMainRenderChild)
  private
  public
    function AllocParticles(const AParticlesCount: Integer; const ATextureName: string; const AWithMips: Boolean): IParticlesHandle;
    procedure Select();
    procedure Draw(const AParticles: IParticlesHandle); overload;
    procedure Draw(const AParticles: IParticlesHandleArr); overload;
  end;

implementation

{ TbParticleSystem }

function TbParticleSystem.AllocParticles(const AParticlesCount: Integer; const ATextureName: string; const AWithMips: Boolean): IParticlesHandle;
begin
  //todo
  Assert(False);
  Result := nil;
end;

procedure TbParticleSystem.Select;
begin

end;

procedure TbParticleSystem.Draw(const AParticles: IParticlesHandle);
begin

end;

procedure TbParticleSystem.Draw(const AParticles: IParticlesHandleArr);
begin

end;

{ TParticleVertex }

class function TParticleVertex.Layout: IDataLayout;
begin
  Result := LB.Add('Pos', ctFloat, 3)
              .Add('Dir', ctFloat, 4)
              .Add('Size', ctFloat, 2)
              .Add('ColMult', ctFloat, 4)
              .Add('ColAdd', ctFloat, 4)
              .Add('TexRect', ctFloat, 4)
              .Finish();
end;

end.

