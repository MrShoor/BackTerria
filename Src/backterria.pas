{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit BackTerria;

{$warn 5023 off : no warning about unused units}
interface

uses
  bWorld, bTypes, bLevel, bWork, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('BackTerria', @Register);
end.
