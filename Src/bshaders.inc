//{$Define LOADFROMRES}

const
{$IfnDef LOADFROMRES}
  SHADERS_FROMRES = False;
  SHADERS_DIR = 'D:\Projects\BackTerria\Src\shaders\!Out';
{$Else}
  SHADERS_FROMRES = True;
  SHADERS_DIR = '';
{$EndIf}
