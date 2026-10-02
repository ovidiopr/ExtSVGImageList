{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit ExtSVGImageList;

{$warn 5023 off : no warning about unused units}
interface

uses
  uExtSVGImageList, uExtSVGImageListEditor, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('uExtSVGImageListEditor', @uExtSVGImageListEditor.Register);
end;

initialization
  RegisterPackage('ExtSVGImageList', @Register);
end.
