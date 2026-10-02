unit uExtSVGImageListEditor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ImgList, LCLType, Math, BCSVGViewer, ComponentEditors, uExtSVGImageList;

type

  { TfrmExtSVGImageListEditor }

  TfrmExtSVGImageListEditor = class(TForm)
    BCSVGViewerPreview: TBCSVGViewer;
    btnAdd: TButton;
    btnRemove: TButton;
    btnUp: TButton;
    btnDown: TButton;
    btnReplace: TButton;
    CheckBox_UseSVGAlignment: TCheckBox;
    AlignImageList: TImageList;
    lstboxImages: TListBox;
    SVGOpenDialog: TOpenDialog;
    tbAlign: TToolBar;
    Separator: TToolButton;
    tbAlignTop: TToolButton;
    tbAlignLeft: TToolButton;
    tbAlignCenter: TToolButton;
    tbAlignRight: TToolButton;
    tbAlignVCenter: TToolButton;
    tbAlignBottom: TToolButton;
    procedure btnAddClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnReplaceClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure CheckBox_UseSVGAlignmentChange(Sender: TObject);
    procedure lstboxImagesDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
    procedure lstboxImagesSelectionChange(Sender: TObject; User: boolean);
    procedure tbAlignClick(Sender: TObject);
  private
    FImageList: TExtSVGImageList;
    FModified: Boolean;
    FSyncing: Boolean; // Set while controls are updated from code
    procedure UpdateListBox(ASelectIndex: Integer);
    procedure UpdateButtons;
    procedure UpdatePreview;
    procedure UpdateAlignControls;
    procedure AlignmentChanged;
    procedure MarkModified;
  public
    constructor Create(AImageList: TExtSVGImageList); reintroduce;
    property ImageList: TExtSVGImageList read FImageList;
    property Modified: Boolean read FModified;
  end;

  { TExtSVGImageListEditor }

  TExtSVGImageListEditor = class(TComponentEditor)
  protected
    procedure DoShowEditor;
  public
    procedure ExecuteVerb(Index: Integer); override;
    function  GetVerb({%H-}Index: Integer): String; override;
    function  GetVerbCount: Integer; override;
  end;

procedure Register;

implementation

{$R *.lfm}

const
  EmptySVG = '<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%"/>';
  // Tag of each alignment tool button, see the .lfm
  TagAlignLeft = 0;
  TagAlignCenter = 1;
  TagAlignRight = 2;
  TagAlignTop = 3;
  TagAlignVCenter = 4;
  TagAlignBottom = 5;

procedure Register;
begin
  RegisterComponents('Misc', [TExtSVGImageList]);
  RegisterComponentEditor(TExtSVGImageList, TExtSVGImageListEditor);
end;

function LoadSVGFile(const AFileName: string): string;
var
  Stream: TFileStream;
begin
  Result := '';
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Stream.Size);
  finally
    Stream.Free;
  end;
end;

{ TExtSVGImageListEditor }

procedure TExtSVGImageListEditor.DoShowEditor;
var
  f: TfrmExtSVGImageListEditor;
begin
  f := TfrmExtSVGImageListEditor.Create(Component as TExtSVGImageList);
  try
    f.ShowModal;
    // Only mark the designer dirty when the user actually changed something
    if f.Modified then
      Modified;
  finally
    f.Free;
  end;
end;

procedure TExtSVGImageListEditor.ExecuteVerb(Index: Integer);
begin
  case Index of
    0: DoShowEditor;
  end;
end;

function TExtSVGImageListEditor.GetVerb(Index: Integer): String;
begin
  Result := 'Edit SVG Image List…';
end;

function TExtSVGImageListEditor.GetVerbCount: Integer;
begin
  Result := 1;
end;

{ TfrmExtSVGImageListEditor }

constructor TfrmExtSVGImageListEditor.Create(AImageList: TExtSVGImageList);
begin
  inherited Create(Application);
  FImageList := AImageList;
  FModified := False;

  // Room for the image at the form's PPI, plus a small margin
  lstboxImages.ItemHeight :=  Max(FImageList.HeightForPPI[FImageList.Width, lstboxImages.Font.PixelsPerInch],
                                  Scale96ToForm(16)) + Scale96ToForm(4);

  FSyncing := True;
  try
    CheckBox_UseSVGAlignment.Checked := FImageList.UseSVGAlignment;
  finally
    FSyncing := False;
  end;
  BCSVGViewerPreview.UseSVGAlignment := FImageList.UseSVGAlignment;
  BCSVGViewerPreview.HorizAlign := FImageList.HorizontalAlignment;
  BCSVGViewerPreview.VertAlign := FImageList.VerticalAlignment;
  UpdateAlignControls;

  UpdateListBox(IfThen(FImageList.SVGCount > 0, 0, -1));
end;

procedure TfrmExtSVGImageListEditor.MarkModified;
begin
  FModified := True;
end;

{ List box, buttons and preview }

procedure TfrmExtSVGImageListEditor.UpdateListBox(ASelectIndex: Integer);
var
  i: Integer;
begin
  lstboxImages.Items.BeginUpdate;
  try
    lstboxImages.Items.Clear;
    for i := 0 to FImageList.SVGCount - 1 do
      lstboxImages.Items.Add(IntToStr(i));
  finally
    lstboxImages.Items.EndUpdate;
  end;

  if ASelectIndex >= lstboxImages.Count then
    ASelectIndex := lstboxImages.Count - 1;
  lstboxImages.ItemIndex := ASelectIndex;

  UpdateButtons;
  UpdatePreview;
end;

procedure TfrmExtSVGImageListEditor.UpdateButtons;
var
  Idx, Cnt: Integer;
begin
  Idx := lstboxImages.ItemIndex;
  Cnt := lstboxImages.Count;
  btnUp.Enabled := Idx > 0;
  btnDown.Enabled := (Idx >= 0) and (Idx < Cnt - 1);
  btnRemove.Enabled := Idx >= 0;
  btnReplace.Enabled := Idx >= 0;
end;

procedure TfrmExtSVGImageListEditor.UpdatePreview;
begin
  if (lstboxImages.ItemIndex >= 0) and (lstboxImages.ItemIndex < FImageList.SVGCount) then
    BCSVGViewerPreview.SVGString := FImageList.SVGString[lstboxImages.ItemIndex]
  else
    BCSVGViewerPreview.SVGString := EmptySVG;
end;

procedure TfrmExtSVGImageListEditor.lstboxImagesSelectionChange(Sender: TObject; User: boolean);
begin
  UpdateButtons;
  UpdatePreview;
end;

{ Button handlers }

procedure TfrmExtSVGImageListEditor.btnAddClick(Sender: TObject);
var
  i, FirstNew: Integer;
  Errors: TStringList;
begin
  if not SVGOpenDialog.Execute then Exit;

  FirstNew := FImageList.SVGCount;
  Errors := TStringList.Create;
  try
    // One raster rebuild for all the selected files
    FImageList.BeginUpdate;
    try
      for i := 0 to SVGOpenDialog.Files.Count - 1 do
        try
          FImageList.Add(LoadSVGFile(SVGOpenDialog.Files[i]));
          MarkModified;
        except
          on E: Exception do
            Errors.Add(ExtractFileName(SVGOpenDialog.Files[i]) + ': ' + E.Message);
        end;
    finally
      FImageList.EndUpdate;
    end;

    if FImageList.SVGCount > FirstNew then
      UpdateListBox(FImageList.SVGCount - 1);

    if Errors.Count > 0 then
      MessageDlg('Some files could not be added', 'These files are not valid SVG images:' +
                 LineEnding + LineEnding + Errors.Text, mtError, [mbOK], 0);
  finally
    Errors.Free;
  end;
end;

procedure TfrmExtSVGImageListEditor.btnRemoveClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := lstboxImages.ItemIndex;
  if Idx < 0 then Exit;
  FImageList.Remove(Idx);
  MarkModified;
  UpdateListBox(Idx); // Clamped to the new last item if needed
end;

procedure TfrmExtSVGImageListEditor.btnReplaceClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := lstboxImages.ItemIndex;
  if Idx < 0 then Exit;
  if not SVGOpenDialog.Execute then Exit;
  try
    // With multi-selection enabled, FileName is the first selected file
    FImageList.Replace(Idx, LoadSVGFile(SVGOpenDialog.FileName));
  except
    on E: Exception do
    begin
      MessageDlg('Cannot replace the image',
        ExtractFileName(SVGOpenDialog.FileName) + ': ' + E.Message, mtError, [mbOK], 0);
      Exit;
    end;
  end;
  MarkModified;
  UpdateListBox(Idx);
end;

procedure TfrmExtSVGImageListEditor.btnUpClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := lstboxImages.ItemIndex;
  if Idx <= 0 then Exit;
  FImageList.Exchange(Idx, Idx - 1);
  MarkModified;
  UpdateListBox(Idx - 1);
end;

procedure TfrmExtSVGImageListEditor.btnDownClick(Sender: TObject);
var
  Idx: Integer;
begin
  Idx := lstboxImages.ItemIndex;
  if (Idx < 0) or (Idx >= lstboxImages.Count - 1) then Exit;
  FImageList.Exchange(Idx, Idx + 1);
  MarkModified;
  UpdateListBox(Idx + 1);
end;

{ List box drawing }

procedure TfrmExtSVGImageListEditor.lstboxImagesDrawItem(Control: TWinControl; Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  Res: TScaledImageListResolution;
  C: TCanvas;
  X, TextY: Integer;
begin
  C := lstboxImages.Canvas;
  if odSelected in State then
  begin
    C.Brush.Color := clHighlight;
    C.Font.Color := clHighlightText;
  end
  else
  begin
    C.Brush.Color := clWindow;
    C.Font.Color := clWindowText;
  end;
  C.FillRect(ARect);

  if (Index < 0) or (Index >= FImageList.Count) then Exit;

  // Draw the actual raster image that controls will use, at the size they
  // will use it, so the preview cannot disagree with the result
  X := ARect.Left + Scale96ToForm(2);
  Res := FImageList.ResolutionForPPI[FImageList.Width, lstboxImages.Font.PixelsPerInch, lstboxImages.GetCanvasScaleFactor];
  Res.Draw(C, X, ARect.Top + (ARect.Height - Res.Height) div 2, Index);

  Inc(X, Res.Width + Scale96ToForm(6));
  TextY := ARect.Top + (ARect.Height - C.TextHeight('0')) div 2;
  C.Brush.Style := bsClear;
  C.TextOut(X, TextY, IntToStr(Index));
  C.Brush.Style := bsSolid;
end;

{ Alignment }

procedure TfrmExtSVGImageListEditor.UpdateAlignControls;
begin
  tbAlignLeft.Down := FImageList.HorizontalAlignment = taLeftJustify;
  tbAlignCenter.Down := FImageList.HorizontalAlignment = taCenter;
  tbAlignRight.Down := FImageList.HorizontalAlignment = taRightJustify;
  tbAlignTop.Down := FImageList.VerticalAlignment = tlTop;
  tbAlignVCenter.Down := FImageList.VerticalAlignment = tlCenter;
  tbAlignBottom.Down := FImageList.VerticalAlignment = tlBottom;
  // The alignment buttons only apply when the SVG's own alignment is not used
  tbAlign.Enabled := not FImageList.UseSVGAlignment;
end;

procedure TfrmExtSVGImageListEditor.AlignmentChanged;
begin
  MarkModified;
  BCSVGViewerPreview.UseSVGAlignment := FImageList.UseSVGAlignment;
  BCSVGViewerPreview.HorizAlign := FImageList.HorizontalAlignment;
  BCSVGViewerPreview.VertAlign := FImageList.VerticalAlignment;
  UpdateAlignControls;
  lstboxImages.Invalidate; // The raster images have been rebuilt
end;

procedure TfrmExtSVGImageListEditor.CheckBox_UseSVGAlignmentChange(Sender: TObject);
begin
  if FSyncing then Exit;
  if FImageList.UseSVGAlignment = CheckBox_UseSVGAlignment.Checked then Exit;
  FImageList.UseSVGAlignment := CheckBox_UseSVGAlignment.Checked;
  AlignmentChanged;
end;

procedure TfrmExtSVGImageListEditor.tbAlignClick(Sender: TObject);
var
  NewH: TAlignment;
  NewV: TTextLayout;
begin
  NewH := FImageList.HorizontalAlignment;
  NewV := FImageList.VerticalAlignment;
  case (Sender as TToolButton).Tag of
    TagAlignLeft: NewH := taLeftJustify;
    TagAlignCenter: NewH := taCenter;
    TagAlignRight: NewH := taRightJustify;
    TagAlignTop: NewV := tlTop;
    TagAlignVCenter: NewV := tlCenter;
    TagAlignBottom: NewV := tlBottom;
  end;

  if (NewH = FImageList.HorizontalAlignment) and
     (NewV = FImageList.VerticalAlignment) then
  begin
    UpdateAlignControls; // Restore the Down state, nothing changed
    Exit;
  end;

  FImageList.BeginUpdate; // A single rebuild
  try
    FImageList.HorizontalAlignment := NewH;
    FImageList.VerticalAlignment := NewV;
  finally
    FImageList.EndUpdate;
  end;
  AlignmentChanged;
end;

initialization
  {$I ExtSVGImageList.lrs}

end.
