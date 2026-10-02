unit uExtSVGImageList;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, ImgList, FGL, XMLConf,
  BGRABitmap, BGRABitmapTypes, BGRASVG;

type
  TListOfTBGRASVG = specialize TFPGObjectList<TBGRASVG>;

  TExtSVGImageList = class;

  // An entry cannot be rendered while the raster images are being built
  TExtSVGRenderErrorEvent = procedure(Sender: TObject; AIndex: Integer; E: Exception) of object;

  { TExtSVGScaleItem }

  // One extra rendition, as a percentage of the image list's Width/Height
  TExtSVGScaleItem = class(TCollectionItem)
  private
    FPercent: Integer;
    procedure SetPercent(AValue: Integer);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(Source: TPersistent); override;
  published
    property Percent: Integer read FPercent write SetPercent default 100;
  end;

  { TExtSVGScaleCollection }

  TExtSVGScaleCollection = class(TOwnedCollection)
  private
    FImageList: TExtSVGImageList;
    function GetItem(AIndex: Integer): TExtSVGScaleItem;
  protected
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AImageList: TExtSVGImageList); reintroduce;
    function Add(APercent: Integer): TExtSVGScaleItem; reintroduce;
    property Items[AIndex: Integer]: TExtSVGScaleItem read GetItem; default;
  end;

  { TExtSVGImageList }

  // Inherits from TImageList so standard LCL controls can consume it natively
  TExtSVGImageList = class(TImageList)
  private
    FItems: TStringList;
    FSVGCache: TListOfTBGRASVG;
    FReferenceDPI: Integer;
    FUseSVGAlignment: Boolean;
    FHorizontalAlignment: TAlignment;
    FVerticalAlignment: TTextLayout;
    FRasterized: Boolean;
    FRasterizing: Boolean;
    FInUpdate: Boolean;
    FRasterWidths: TIntegerDynArray;
    FDataLineBreak: TTextLineBreakStyle;
    FScales: TExtSVGScaleCollection;
    FOnRenderError: TExtSVGRenderErrorEvent;
    procedure ReadSVGData(Stream: TStream);
    procedure WriteSVGData(Stream: TStream);
    procedure SkipLegacyBitmapData(Stream: TStream);
    procedure CheckSVGIndex(AIndex: Integer);
    procedure ClearSVGCache;
    function  GetCachedSVG(AIndex: Integer): TBGRASVG;
    function  ParseSVG(const ASVG: string): TBGRASVG;
    function  DedupSortedWidths(const AWidths: array of Integer): TIntegerDynArray;
    function  CreateRasterBitmap(AIndex, AWidth, AHeight: Integer): TBitmap;
    function  AddRasterItem(AIndex: Integer): Integer;
    function  CanUpdateRasterIncrementally: Boolean;
    procedure SetReferenceDPI(AValue: Integer);
    procedure SetUseSVGAlignment(AValue: Boolean);
    procedure SetHorizontalAlignment(AValue: TAlignment);
    procedure SetVerticalAlignment(AValue: TTextLayout);
    procedure ReadScalesEmpty(Reader: TReader);
    procedure WriteScalesEmpty(Writer: TWriter);
    procedure SetScales(AValue: TExtSVGScaleCollection);
    function  IsScalesStored: Boolean;
    procedure ScalesChanged;
    function  GetWidth: Integer;
    procedure SetWidth(AValue: Integer);
    function  GetHeight: Integer;
    procedure SetHeight(AValue: Integer);
  protected
    procedure Load(const XMLConf: TXMLConfig);
    procedure Save(const XMLConf: TXMLConfig);
    procedure DefineProperties(Filer: TFiler); override;
    procedure Loaded; override;
    procedure DoAfterUpdateStarted; override;
    procedure DoBeforeUpdateEnded; override;
    function  GetSVGCount: Integer;
    function  GetSVGString(AIndex: Integer): string;
    procedure Rasterize;
    procedure QueryRasterize;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure Assign(Source: TPersistent); override;

    // SVG management
    function  Add(const ASVG: string): Integer; overload;
    procedure Remove(AIndex: Integer);
    procedure Exchange(AIndex1, AIndex2: Integer);
    procedure Replace(AIndex: Integer; const ASVG: string); overload;
    procedure Delete(AIndex: Integer); reintroduce;
    procedure Move(ACurIndex, ANewIndex: Integer); reintroduce;
    procedure Clear; reintroduce;
    procedure SetSize(AWidth, AHeight: Integer); reintroduce;

    function  GetScaledSize(ATargetDPI: Integer): TSize;

    // Return a TBGRABitmap rendered at the requested pixel size
    function GetBGRABitmap(AIndex, AWidth, AHeight: Integer): TBGRABitmap; overload;
    function GetBGRABitmap(AIndex, AWidth, AHeight: Integer;
                           AUseSVGAlignment: Boolean): TBGRABitmap; overload;

    // Return a 32-bit TBitmap (with alpha) rendered at the requested pixel size
    function GetBitmap(AIndex, AWidth, AHeight: Integer): TBitmap; overload;
    function GetBitmap(AIndex, AWidth, AHeight: Integer;
                       AUseSVGAlignment: Boolean): TBitmap; overload;

    // Draw onto a TCanvas at LCL coordinates
    procedure Draw(AIndex: Integer; AControl: TControl; ACanvas: TCanvas;
                   ALeft, ATop, AWidth, AHeight: Integer); overload;
    procedure Draw(AIndex: Integer; AControl: TControl; ACanvas: TCanvas;
                   ALeft, ATop, AWidth, AHeight: Integer;
                   AUseSVGAlignment: Boolean; AOpacity: Byte = 255); overload;

    // Draw onto a TCanvas with an explicit canvas-scale factor
    procedure Draw(AIndex: Integer; ACanvasScale: Single; ACanvas: TCanvas;
                   ALeft, ATop, AWidth, AHeight: Integer); overload;
    procedure Draw(AIndex: Integer; ACanvasScale: Single; ACanvas: TCanvas;
                   ALeft, ATop, AWidth, AHeight: Integer;
                   AUseSVGAlignment: Boolean; AOpacity: Byte = 255); overload;

    // Draw directly onto a TBGRABitmap within the given rectangle
    procedure Draw(AIndex: Integer; ABitmap: TBGRABitmap;
                   const ARectF: TRectF); overload;
    procedure Draw(AIndex: Integer; ABitmap: TBGRABitmap;
                   const ARectF: TRectF; AUseSVGAlignment: Boolean); overload;

    // Replace the extra scales (percentages of Width/Height, 1..1000)
    // An empty array means "100 % only"
    procedure SetScaling(const APercents: array of Integer);

    // Populate the underlying raster image list with bitmaps
    procedure PopulateImageList(const AWidths: array of Integer);

    // The raw SVG source for entry AIndex
    property SVGString[AIndex: Integer]: string read GetSVGString;
    // Number of SVG entries (equal to the inherited Count once rasterized)
    property SVGCount: Integer read GetSVGCount;
  published
    // Shadow Width and Height to trigger a re-rasterization
    property Width:  Integer read GetWidth  write SetWidth  default 16;
    property Height: Integer read GetHeight write SetHeight default 16;

    property ReferenceDPI: Integer read FReferenceDPI write SetReferenceDPI default 96;
    property UseSVGAlignment: Boolean read FUseSVGAlignment write SetUseSVGAlignment default False;
    property HorizontalAlignment: TAlignment read FHorizontalAlignment write SetHorizontalAlignment default taCenter;
    property VerticalAlignment: TTextLayout read FVerticalAlignment write SetVerticalAlignment default tlCenter;
    // Additional scales besides 100 %, as a percentage of Width/Height
    property Scales: TExtSVGScaleCollection read FScales write SetScales stored IsScalesStored;

    property OnRenderError: TExtSVGRenderErrorEvent read FOnRenderError write FOnRenderError;
  end;

implementation

uses
  GraphType, LCLType, IntfGraphics, LazUTF8, XMLRead;

{ FPC < 3.2.3 compatibility shim: TXMLConfig.LoadFromStream is missing }
{$IF FPC_FULLVERSION < 30203}
type
  TPatchedXMLConfig = class(TXMLConfig)
  public
    procedure LoadFromStream(S: TStream);
  end;

procedure TPatchedXMLConfig.LoadFromStream(S: TStream);
begin
  FreeAndNil(Doc);
  ReadXMLFile(Doc, S);
  FModified := False;
  if (Doc.DocumentElement = nil) or (Doc.DocumentElement.NodeName <> RootName) then
    raise EXMLConfigError.Create('TExtSVGImageList: invalid SVG data (wrong XML root element)');
end;
{$ENDIF}

const
  // Default extra scales (the 100 % one is always generated)
  DefaultScalePercents: array[0..2] of Integer = (125, 150, 200);
  MinScalePercent = 1;
  MaxScalePercent = 1000;

// Copy a TBGRABitmap into a 32-bit TBitmap, keeping the alpha channel
function BGRAToBitmap(ASource: TBGRABitmap): TBitmap;
var
  Img: TLazIntfImage;
  x, y: Integer;
  p: PBGRAPixel;
begin
  Img := TLazIntfImage.Create(ASource.Width, ASource.Height, [riqfRGB, riqfAlpha]);
  try
    Img.CreateData;
    for y := 0 to ASource.Height - 1 do
    begin
      p := ASource.ScanLine[y];
      for x := 0 to ASource.Width - 1 do
      begin
        Img.Colors[x, y] := BGRAToFPColor(p^);
        Inc(p);
      end;
    end;
    Result := TBitmap.Create;
    try
      Result.LoadFromIntfImage(Img);
    except
      Result.Free;
      raise;
    end;
  finally
    Img.Free;
  end;
end;

{ TExtSVGScaleItem }

constructor TExtSVGScaleItem.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FPercent := 100;
end;

procedure TExtSVGScaleItem.Assign(Source: TPersistent);
begin
  if Source is TExtSVGScaleItem then
    Percent := TExtSVGScaleItem(Source).Percent
  else
    inherited Assign(Source);
end;

function TExtSVGScaleItem.GetDisplayName: string;
begin
  Result := IntToStr(FPercent) + ' %';
end;

procedure TExtSVGScaleItem.SetPercent(AValue: Integer);
begin
  // Clamped rather than raising, so a hand-edited LFM still loads
  if AValue < MinScalePercent then AValue := MinScalePercent;
  if AValue > MaxScalePercent then AValue := MaxScalePercent;
  if FPercent = AValue then Exit;

  FPercent := AValue;
  Changed(False);
end;

{ TExtSVGScaleCollection }

constructor TExtSVGScaleCollection.Create(AImageList: TExtSVGImageList);
begin
  inherited Create(AImageList, TExtSVGScaleItem);
  FImageList := AImageList;
end;

function TExtSVGScaleCollection.GetItem(AIndex: Integer): TExtSVGScaleItem;
begin
  Result := TExtSVGScaleItem(inherited Items[AIndex]);
end;

function TExtSVGScaleCollection.Add(APercent: Integer): TExtSVGScaleItem;
begin
  Result := TExtSVGScaleItem(inherited Add);
  Result.Percent := APercent;
end;

procedure TExtSVGScaleCollection.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Assigned(FImageList) then
    FImageList.ScalesChanged;
end;

{ TExtSVGImageList }

{ Streaming }

procedure TExtSVGImageList.ReadSVGData(Stream: TStream);

  // Detect which line-ending convention the stream uses
  function GetLineEnding(AStream: TStream; AMaxLookAhead: Integer = 4096): TTextLineBreakStyle;
  var
    c: Char;
    i: Integer;
  begin
    c := #0;
    for i := 0 to AMaxLookAhead - 1 do
    begin
      if AStream.Read(c, SizeOf(c)) = 0 then Break;
      case c of
        #10: Exit(tlbsLF);
        #13:
          begin
            if AStream.Read(c, SizeOf(c)) = 0 then c := #0;
            if c = #10 then
              Exit(tlbsCRLF)
            else
              Exit(tlbsCR);
          end;
      end;
    end;
    Result := DefaultTextLineBreakStyle;
  end;

var
  XMLConf: TXMLConfig;
begin
  XMLConf := TXMLConfig.Create(nil);
  try
    Stream.Position := 0;
    FDataLineBreak := GetLineEnding(Stream);
    Stream.Position := 0;
    {$IF FPC_FULLVERSION < 30203}
    TPatchedXMLConfig(XMLConf).LoadFromStream(Stream);
    {$ELSE}
    XMLConf.LoadFromStream(Stream);
    {$ENDIF}
    Load(XMLConf);
  finally
    XMLConf.Free;
  end;
end;

procedure TExtSVGImageList.WriteSVGData(Stream: TStream);
var
  XMLConf: TXMLConfig;
  TempStream: TStringStream;
  NormalizedData: string;
begin
  XMLConf := TXMLConfig.Create(nil);
  TempStream := TStringStream.Create('');
  try
    Save(XMLConf);
    XMLConf.SaveToStream(TempStream);
    NormalizedData := AdjustLineBreaks(TempStream.DataString, FDataLineBreak);
    if NormalizedData <> '' then
      Stream.WriteBuffer(NormalizedData[1], Length(NormalizedData));
  finally
    TempStream.Free;
    XMLConf.Free;
  end;
end;

procedure TExtSVGImageList.SkipLegacyBitmapData(Stream: TStream);
begin
  // Older versions of this component (through TCustomImageList) also stored
  // the rasterized images. They are regenerated from the SVG sources, so the
  // data is simply ignored; it disappears from the LFM on the next save.
end;

procedure TExtSVGImageList.Load(const XMLConf: TXMLConfig);
var
  i, ItemCount: Integer;
begin
  FItems.Clear;
  ClearSVGCache;
  ItemCount := XMLConf.GetValue('Count', 0);
  for i := 0 to ItemCount - 1 do
  begin
    // TXMLConfig works with UnicodeString; LCL strings are UTF-8
    FItems.Add(UTF16ToUTF8(XMLConf.GetValue(UTF8ToUTF16('Item' + IntToStr(i) + '/SVG'), '')));
    FSVGCache.Add(nil); // Parsed lazily on first use
  end;
  FRasterized := False;
end;

procedure TExtSVGImageList.Save(const XMLConf: TXMLConfig);
var
  i: Integer;
begin
  XMLConf.SetValue('Count', FItems.Count);
  for i := 0 to FItems.Count - 1 do
    XMLConf.SetValue(UTF8ToUTF16('Item' + IntToStr(i) + '/SVG'),
      UTF8ToUTF16(AdjustLineBreaks(FItems[i], FDataLineBreak)));
end;

procedure TExtSVGImageList.DefineProperties(Filer: TFiler);
type
  TDefinePropertiesProc = procedure(AFiler: TFiler) of object;
var
  M: TMethod;

  function ItemsDiffer: Boolean;
  begin
    if Filer.Ancestor is TExtSVGImageList then
      Result := not FItems.Equals(TExtSVGImageList(Filer.Ancestor).FItems)
    else
      Result := FItems.Count > 0;
  end;

begin
  // TCustomImageList.DefineProperties would stream the rasterized images
  // They are rebuilt from the SVG sources, storing them only bloats the LFM
  // Skip it and call TComponent.DefineProperties directly
  M.Code := @TComponent.DefineProperties;
  M.Data := Self;
  TDefinePropertiesProc(M)(Filer);

  // Still accept these when reading LFMs saved by older versions
  Filer.DefineBinaryProperty('Bitmap', @SkipLegacyBitmapData, nil, False);
  Filer.DefineBinaryProperty('BitmapAdv', @SkipLegacyBitmapData, nil, False);

  Filer.DefineBinaryProperty('Items', @ReadSVGData, @WriteSVGData, ItemsDiffer);
  Filer.DefineProperty('ScalesEmpty', @ReadScalesEmpty, @WriteScalesEmpty, FScales.Count = 0);
end;

procedure TExtSVGImageList.ReadScalesEmpty(Reader: TReader);
begin
  if Reader.ReadBoolean then
    FScales.Clear;
end;

procedure TExtSVGImageList.WriteScalesEmpty(Writer: TWriter);
begin
  Writer.WriteBoolean(True);
end;

procedure TExtSVGImageList.Loaded;
begin
  inherited Loaded;
  QueryRasterize; // Build the raster images once the component is streamed in
end;

{ Update batching, hooked into the inherited BeginUpdate/EndUpdate }

procedure TExtSVGImageList.DoAfterUpdateStarted;
begin
  inherited DoAfterUpdateStarted;
  if not FRasterizing then
    FInUpdate := True;
end;

procedure TExtSVGImageList.DoBeforeUpdateEnded;
begin
  if not FRasterizing then
  begin
    FInUpdate := False;
    // Rebuild here, while the update is still open, so consumers are
    // notified only once by the inherited EndUpdate
    if not FRasterized then
      Rasterize;
  end;
  inherited DoBeforeUpdateEnded;
end;

{ Construction/destruction }

constructor TExtSVGImageList.Create(AOwner: TComponent);
var
  Coll: TExtSVGScaleCollection;
  i: Integer;
begin
  inherited Create(AOwner);
  FItems := TStringList.Create;
  FSVGCache := TListOfTBGRASVG.Create(True);
  FReferenceDPI := 96;
  FUseSVGAlignment := False;
  FHorizontalAlignment := taCenter;
  FVerticalAlignment := tlCenter;
  FDataLineBreak := DefaultTextLineBreakStyle;
  Scaled := True; // Required to pick the best resolution for each PPI

  // Fill the defaults before assigning FScales
  Coll := TExtSVGScaleCollection.Create(Self);
  for i := Low(DefaultScalePercents) to High(DefaultScalePercents) do
    Coll.Add(DefaultScalePercents[i]);
  FScales := Coll;

  FRasterized := True; // Empty SVG list, empty raster list: in sync
end;

destructor TExtSVGImageList.Destroy;
begin
  FreeAndNil(FScales);
  FreeAndNil(FSVGCache);
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TExtSVGImageList.Assign(Source: TPersistent);
var
  Src: TExtSVGImageList;
  i: Integer;
begin
  if Source = Self then Exit;
  if Source is TExtSVGImageList then
  begin
    Src := TExtSVGImageList(Source);
    BeginUpdate;
    try
      SetSize(Src.Width, Src.Height);
      FItems.Assign(Src.FItems);
      ClearSVGCache;
      for i := 0 to FItems.Count - 1 do
        FSVGCache.Add(nil);
      FScales.Assign(Src.FScales);
      FReferenceDPI := Src.FReferenceDPI;
      FUseSVGAlignment := Src.FUseSVGAlignment;
      FHorizontalAlignment := Src.FHorizontalAlignment;
      FVerticalAlignment := Src.FVerticalAlignment;
      FDataLineBreak := Src.FDataLineBreak;
      QueryRasterize;
    finally
      EndUpdate; // Rebuilds the raster images
    end;
  end
  else if Source is TCustomImageList then
    raise EConvertError.CreateFmt('Cannot assign a %s to a %s: it has no SVG sources',
                                  [Source.ClassName, ClassName])
  else
    inherited Assign(Source);
end;

procedure TExtSVGImageList.CheckSVGIndex(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    raise ERangeError.CreateFmt('TExtSVGImageList: index %d out of range (SVGCount = %d)',
                                [AIndex, FItems.Count]);
end;

{ SVG cache }

procedure TExtSVGImageList.ClearSVGCache;
begin
  // The list owns its objects, so Clear frees every cached TBGRASVG
  FSVGCache.Clear;
end;

function TExtSVGImageList.ParseSVG(const ASVG: string): TBGRASVG;
begin
  Result := TBGRASVG.CreateFromString(ASVG);
end;

function TExtSVGImageList.GetCachedSVG(AIndex: Integer): TBGRASVG;
begin
  CheckSVGIndex(AIndex);
  Result := FSVGCache[AIndex];
  if Result = nil then
  begin
    Result := ParseSVG(FItems[AIndex]);
    FSVGCache[AIndex] := Result;
  end;
end;

{ Dedup/sort helper }

function TExtSVGImageList.DedupSortedWidths(const AWidths: array of Integer): TIntegerDynArray;
var
  i, j, n, v: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AWidths));
  n := 0;
  for i := 0 to High(AWidths) do
  begin
    if AWidths[i] <= 0 then Continue; // skip invalid entries
    j := 0;
    while (j < n) and (Result[j] <> AWidths[i]) do Inc(j);
    if j = n then  // not a duplicate
    begin
      Result[n] := AWidths[i];
      Inc(n);
    end;
  end;
  SetLength(Result, n);
  // Insertion sort - the array is tiny (typically <= 6 entries)
  for i := 1 to n - 1 do
  begin
    v := Result[i];
    j := i - 1;
    while (j >= 0) and (Result[j] > v) do
    begin
      Result[j + 1] := Result[j];
      Dec(j);
    end;
    Result[j + 1] := v;
  end;
end;

{ Property accessors }

procedure TExtSVGImageList.SetReferenceDPI(AValue: Integer);
begin
  if AValue < 1 then
    raise ERangeError.CreateFmt('TExtSVGImageList: invalid ReferenceDPI %d', [AValue]);
  // Not used by the rasterization, so no rebuild is needed
  FReferenceDPI := AValue;
end;

procedure TExtSVGImageList.SetUseSVGAlignment(AValue: Boolean);
begin
  if FUseSVGAlignment = AValue then Exit;
  FUseSVGAlignment := AValue;
  QueryRasterize;
end;

procedure TExtSVGImageList.SetHorizontalAlignment(AValue: TAlignment);
begin
  if FHorizontalAlignment = AValue then Exit;
  FHorizontalAlignment := AValue;
  QueryRasterize;
end;

procedure TExtSVGImageList.SetVerticalAlignment(AValue: TTextLayout);
begin
  if FVerticalAlignment = AValue then Exit;
  FVerticalAlignment := AValue;
  QueryRasterize;
end;

procedure TExtSVGImageList.SetScales(AValue: TExtSVGScaleCollection);
begin
  FScales.Assign(AValue);
end;

procedure TExtSVGImageList.ScalesChanged;
begin
  if FScales = nil then Exit;
  QueryRasterize;
end;

function TExtSVGImageList.IsScalesStored: Boolean;
var
  i: Integer;
begin
  // An empty collection is streamed through ScalesEmpty instead
  if FScales.Count = 0 then Exit(False);

  // Only streamed when it differs from the defaults
  Result := FScales.Count <> Length(DefaultScalePercents);
  if not Result then
    for i := 0 to FScales.Count - 1 do
      if FScales[i].Percent <> DefaultScalePercents[i] then Exit(True);
end;

procedure TExtSVGImageList.SetScaling(const APercents: array of Integer);
var
  i: Integer;
  Same: Boolean;
begin
  // Validate first, so an invalid array leaves the current scales untouched
  for i := 0 to High(APercents) do
    if (APercents[i] < MinScalePercent) or (APercents[i] > MaxScalePercent) then
      raise ERangeError.CreateFmt('TExtSVGImageList: scale %d%% out of range (%d..%d)',
                                  [APercents[i], MinScalePercent, MaxScalePercent]);

  // Nothing to do (and no needless re-rasterization) if the list is unchanged
  Same := FScales.Count = Length(APercents);
  if Same then
    for i := 0 to High(APercents) do
      if FScales[i].Percent <> APercents[i] then
      begin
        Same := False;
        Break;
      end;
  if Same then Exit;

  // Single collection update: one ScalesChanged, hence a single rebuild
  FScales.BeginUpdate;
  try
    FScales.Clear;
    for i := 0 to High(APercents) do
      FScales.Add(APercents[i]);
  finally
    FScales.EndUpdate;
  end;
end;

function TExtSVGImageList.GetWidth: Integer;
begin
  Result := inherited Width;
end;

procedure TExtSVGImageList.SetWidth(AValue: Integer);
begin
  if inherited Width = AValue then Exit;
  inherited Width := AValue;
  QueryRasterize;
end;

function TExtSVGImageList.GetHeight: Integer;
begin
  Result := inherited Height;
end;

procedure TExtSVGImageList.SetHeight(AValue: Integer);
begin
  if inherited Height = AValue then Exit;
  inherited Height := AValue;
  QueryRasterize;
end;

procedure TExtSVGImageList.SetSize(AWidth, AHeight: Integer);
begin
  if (inherited Width = AWidth) and (inherited Height = AHeight) then Exit;
  SetWidthHeight(AWidth, AHeight); // what the inherited SetSize does (LCL 4+)
  QueryRasterize;
end;

{ Rasterization pipeline }

function TExtSVGImageList.CreateRasterBitmap(AIndex, AWidth, AHeight: Integer): TBitmap;
var
  Bmp: TBGRABitmap;
begin
  Bmp := TBGRABitmap.Create(AWidth, AHeight); // transparent
  try
    try
      Draw(AIndex, Bmp, RectF(0, 0, AWidth, AHeight), FUseSVGAlignment);
    except
      on E: Exception do
      begin
        // Keep a transparent placeholder so the raster indexes stay aligned
        // with the SVG entries, and report the problem
        Bmp.FillTransparent;
        if Assigned(FOnRenderError) then
          FOnRenderError(Self, AIndex, E);
      end;
    end;
    Result := BGRAToBitmap(Bmp);
  finally
    Bmp.Free;
  end;
end;

function TExtSVGImageList.AddRasterItem(AIndex: Integer): Integer;
var
  Bitmaps: array of TCustomBitmap;
  i, H: Integer;
begin
  Bitmaps := nil;
  SetLength(Bitmaps, Length(FRasterWidths)); // zero-filled
  try
    for i := 0 to High(Bitmaps) do
    begin
      // Use the inherited height computation, so that each bitmap has exactly
      // the size of its resolution and is not resampled by the image list
      H := HeightForWidth[FRasterWidths[i]];
      if H <= 0 then H := FRasterWidths[i];
      Bitmaps[i] := CreateRasterBitmap(AIndex, FRasterWidths[i], H);
    end;
    Result := AddMultipleResolutions(Bitmaps);
  finally
    for i := 0 to High(Bitmaps) do
      Bitmaps[i].Free;
  end;
end;

function TExtSVGImageList.CanUpdateRasterIncrementally: Boolean;
begin
  Result := FRasterized and not FInUpdate and not FRasterizing and
            (Length(FRasterWidths) > 0) and
            (ComponentState*[csLoading, csDestroying] = []) and
            (inherited Count = FItems.Count);
end;

procedure TExtSVGImageList.Rasterize;
var
  BaseWidth, i: Integer;
  Widths: TIntegerDynArray;
begin
  if FRasterizing or (ComponentState*[csLoading, csDestroying] <> []) then Exit;
  if FScales = nil then Exit;

  BaseWidth := Width;
  if BaseWidth <= 0 then BaseWidth := 16;

  // 100 % is always generated; Scales adds the extra scales
  Widths := nil;
  SetLength(Widths, FScales.Count + 1);
  Widths[0] := BaseWidth;
  for i := 0 to FScales.Count - 1 do
    Widths[i + 1] := MulDiv(BaseWidth, FScales[i].Percent, 100);

  PopulateImageList(Widths); // dedups and sorts
end;

procedure TExtSVGImageList.QueryRasterize;
begin
  FRasterized := False;
  // Deferred while loading (Loaded rebuilds) and inside BeginUpdate/EndUpdate
  if FInUpdate or (ComponentState*[csLoading, csDestroying] <> []) then Exit;
  Rasterize;
end;

procedure TExtSVGImageList.PopulateImageList(const AWidths: array of Integer);
var
  j: Integer;
  Widths: TIntegerDynArray;
begin
  if FRasterizing then Exit;

  // Deduplicate and sort, to avoid duplicate sizes
  Widths := DedupSortedWidths(AWidths);
  if Length(Widths) = 0 then Exit;

  FRasterizing := True;
  BeginUpdate;
  try
    inherited Clear; // Removes the images and every registered resolution
    Scaled := True;
    RegisterResolutions(Widths);
    FRasterWidths := Widths;
    for j := 0 to SVGCount - 1 do
      AddRasterItem(j);
    MarkAsChanged;
    FRasterized := True;
  finally
    EndUpdate;
    FRasterizing := False;
  end;
end;

{ Public SVG management }

function TExtSVGImageList.GetSVGCount: Integer;
begin
  Result := FItems.Count;
end;

function TExtSVGImageList.GetSVGString(AIndex: Integer): string;
begin
  CheckSVGIndex(AIndex);
  Result := FItems[AIndex];
end;

function TExtSVGImageList.Add(const ASVG: string): Integer;
var
  SVG: TBGRASVG;
begin
  SVG := ParseSVG(ASVG); // Raises on invalid input, nothing changed yet
  try
    Result := FItems.Add(ASVG);
    FSVGCache.Add(SVG);
    SVG := nil;
  finally
    SVG.Free;
  end;

  if CanUpdateRasterIncrementally then
  begin
    AddRasterItem(Result);
    MarkAsChanged;
    Change;
  end
  else
    QueryRasterize;
end;

procedure TExtSVGImageList.Remove(AIndex: Integer);
var
  Incremental: Boolean;
begin
  CheckSVGIndex(AIndex);
  Incremental := CanUpdateRasterIncrementally;
  FItems.Delete(AIndex);
  FSVGCache.Delete(AIndex);
  if Incremental then
    inherited Delete(AIndex) // Notifies consumers itself
  else
    QueryRasterize;
end;

procedure TExtSVGImageList.Exchange(AIndex1, AIndex2: Integer);
var
  Incremental: Boolean;
  Lo, Hi: Integer;
begin
  CheckSVGIndex(AIndex1);
  CheckSVGIndex(AIndex2);
  if AIndex1 = AIndex2 then Exit;
  Incremental := CanUpdateRasterIncrementally;
  FItems.Exchange(AIndex1, AIndex2);
  FSVGCache.Exchange(AIndex1, AIndex2);
  if Incremental then
  begin
    if AIndex1 < AIndex2 then
    begin
      Lo := AIndex1;
      Hi := AIndex2;
    end
    else
    begin
      Lo := AIndex2;
      Hi := AIndex1;
    end;
    BeginUpdate;
    try
      inherited Move(Lo, Hi);     // Lo goes to Hi, old Hi shifts to Hi-1
      inherited Move(Hi - 1, Lo); // old Hi goes to Lo
    finally
      EndUpdate;
    end;
  end
  else
    QueryRasterize;
end;

procedure TExtSVGImageList.Move(ACurIndex, ANewIndex: Integer);
var
  Incremental: Boolean;
begin
  CheckSVGIndex(ACurIndex);
  CheckSVGIndex(ANewIndex);
  if ACurIndex = ANewIndex then Exit;
  Incremental := CanUpdateRasterIncrementally;
  FItems.Move(ACurIndex, ANewIndex);
  FSVGCache.Move(ACurIndex, ANewIndex);
  if Incremental then
    inherited Move(ACurIndex, ANewIndex)
  else
    QueryRasterize;
end;

procedure TExtSVGImageList.Replace(AIndex: Integer; const ASVG: string);
var
  SVG: TBGRASVG;
  Incremental: Boolean;
  NewIndex: Integer;
begin
  CheckSVGIndex(AIndex);
  SVG := ParseSVG(ASVG); // Raises on invalid input, nothing changed yet
  Incremental := CanUpdateRasterIncrementally;
  FItems[AIndex] := ASVG;
  FSVGCache[AIndex] := SVG; // The owning list frees the old object

  if Incremental then
  begin
    BeginUpdate;
    try
      NewIndex := AddRasterItem(AIndex);
      inherited Move(NewIndex, AIndex);
      inherited Delete(AIndex + 1);
    finally
      EndUpdate;
    end;
  end
  else
    QueryRasterize;
end;

procedure TExtSVGImageList.Delete(AIndex: Integer);
begin
  if AIndex = -1 then
    Clear
  else
    Remove(AIndex);
end;

procedure TExtSVGImageList.Clear;
begin
  FItems.Clear;
  ClearSVGCache;
  QueryRasterize;
end;

{ Sizing }

function TExtSVGImageList.GetScaledSize(ATargetDPI: Integer): TSize;
begin
  Result.cx := MulDiv(Width,  ATargetDPI, FReferenceDPI);
  Result.cy := MulDiv(Height, ATargetDPI, FReferenceDPI);
end;

{ Rendering - every path goes through Draw(AIndex, TBGRABitmap, ...) }

function TExtSVGImageList.GetBGRABitmap(AIndex, AWidth, AHeight: Integer): TBGRABitmap;
begin
  Result := GetBGRABitmap(AIndex, AWidth, AHeight, FUseSVGAlignment);
end;

function TExtSVGImageList.GetBGRABitmap(AIndex, AWidth, AHeight: Integer; AUseSVGAlignment: Boolean): TBGRABitmap;
begin
  GetCachedSVG(AIndex); // Validate the index and parse before allocating
  Result := TBGRABitmap.Create(AWidth, AHeight);
  try
    Draw(AIndex, Result, RectF(0, 0, AWidth, AHeight), AUseSVGAlignment);
  except
    Result.Free;
    raise;
  end;
end;

function TExtSVGImageList.GetBitmap(AIndex, AWidth, AHeight: Integer): TBitmap;
begin
  Result := GetBitmap(AIndex, AWidth, AHeight, FUseSVGAlignment);
end;

function TExtSVGImageList.GetBitmap(AIndex, AWidth, AHeight: Integer; AUseSVGAlignment: Boolean): TBitmap;
var
  Bmp: TBGRABitmap;
begin
  Bmp := GetBGRABitmap(AIndex, AWidth, AHeight, AUseSVGAlignment);
  try
    Result := BGRAToBitmap(Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; AControl: TControl;
                                ACanvas: TCanvas; ALeft, ATop, AWidth, AHeight: Integer);
begin
  Draw(AIndex, AControl, ACanvas, ALeft, ATop, AWidth, AHeight, FUseSVGAlignment);
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; AControl: TControl;
                                ACanvas: TCanvas; ALeft, ATop, AWidth, AHeight: Integer;
                                AUseSVGAlignment: Boolean; AOpacity: Byte);
var
  Scale: Single;
begin
  if Assigned(AControl) then
    Scale := AControl.GetCanvasScaleFactor
  else
    Scale := 1;
  Draw(AIndex, Scale, ACanvas, ALeft, ATop, AWidth, AHeight, AUseSVGAlignment, AOpacity);
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; ACanvasScale: Single;
                                ACanvas: TCanvas; ALeft, ATop, AWidth, AHeight: Integer);
begin
  Draw(AIndex, ACanvasScale, ACanvas, ALeft, ATop, AWidth, AHeight, FUseSVGAlignment);
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; ACanvasScale: Single;
                                ACanvas: TCanvas; ALeft, ATop, AWidth, AHeight: Integer;
                                AUseSVGAlignment: Boolean; AOpacity: Byte);
var
  Bmp: TBGRABitmap;
begin
  if (AWidth <= 0) or (AHeight <= 0) or (ACanvasScale <= 0) or (AOpacity = 0) then Exit;
  Bmp := TBGRABitmap.Create(Round(AWidth*ACanvasScale), Round(AHeight*ACanvasScale));
  try
    Draw(AIndex, Bmp, RectF(0, 0, Bmp.Width, Bmp.Height), AUseSVGAlignment);
    if AOpacity < 255 then
      Bmp.ApplyGlobalOpacity(AOpacity);
    Bmp.Draw(ACanvas, Rect(ALeft, ATop, ALeft + AWidth, ATop + AHeight), False);
  finally
    Bmp.Free;
  end;
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; ABitmap: TBGRABitmap; const ARectF: TRectF);
begin
  Draw(AIndex, ABitmap, ARectF, FUseSVGAlignment);
end;

procedure TExtSVGImageList.Draw(AIndex: Integer; ABitmap: TBGRABitmap; const ARectF: TRectF; AUseSVGAlignment: Boolean);
var
  SVG: TBGRASVG;
begin
  SVG := GetCachedSVG(AIndex);
  if AUseSVGAlignment then
    SVG.StretchDraw(ABitmap.Canvas2D, ARectF, True)
  else
    SVG.StretchDraw(ABitmap.Canvas2D, FHorizontalAlignment, FVerticalAlignment,
                    ARectF.Left, ARectF.Top, ARectF.Width, ARectF.Height);
end;

end.
