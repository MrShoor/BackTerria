unit bWork;

{$IfDef FPC}
  {$mode objfpc}{$H+}
{$EndIf}

interface

uses
  Classes, SysUtils, bWorld, avRes, avTypes, mutils,
  bLevel;

type

  { TbWork }

  TbWork = class (TavMainRenderChild)
  private
    FWorld: TbWorld;
    FFrameBuffer: TavFrameBuffer;
  protected
    property World: TbWorld read FWorld;

    procedure EMUps(var AMsg: TavMessage); message EM_UPS;
  public
    procedure Render; virtual;
    procedure AfterConstruction; override;
  end;

implementation

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

    Main.Clear(Vec(Random,0.2,0.4,1.0), True, Main.Projection.DepthRange.y, True);



    FFrameBuffer.BlitToWindow;
    Main.Present;
  finally
    Main.Unbind;
  end;
end;

procedure TbWork.AfterConstruction;
begin
  inherited AfterConstruction;
  FWorld := TbWorld.Create(Self);
  FFrameBuffer := Create_FrameBufferMultiSampled(Main, [TTextureFormat.RGBA, TTextureFormat.D32f], 8, [true, false]);
end;

end.

