unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, ImgList, shellapi, xc_lib;

type
  TMainForm = class(TForm)
    CloseBtn: TButton;
    ScanBtn: TButton;
    StopBtn: TButton;
    BackBtn: TButton;
    Pages: TPageControl;
    SelectPathTab: TTabSheet;
    ScanProcessTab: TTabSheet;
    ClearResults: TCheckBox;
    ScanProcess: TEdit;
    ScanView: TListView;
    PathView: TTreeView;
    DriveImages: TImageList;
    ReportImages: TImageList;
    Label1: TLabel;
    DBLabel: TLabel;
    LoadedLabel: TLabel;
    VersionLabel: TLabel;
    TabSheet1: TTabSheet;
    Memo1: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure PathViewExpanded(Sender: TObject; Node: TTreeNode);
    procedure PathViewCollapsed(Sender: TObject; Node: TTreeNode);
    procedure ScanBtnClick(Sender: TObject);
    procedure BackBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure PathViewChanging(Sender: TObject; Node: TTreeNode;
      var AllowChange: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
    MainForm: TMainForm;
    engine: pxc_engine;
    unarchfl, scanfile: string;
    stopped: boolean = true;
    scanned, infected: integer;
    path: string = '';
implementation
(* -------------------------------------------------------------------------- *)
function DiskInDrive(const Drive: char): Boolean;
var
    DrvNum: byte;
    EMode : Word;
begin
    result := false;
    DrvNum := ord(Drive);
    if DrvNum >= ord('a') then
        dec(DrvNum, $20);
    EMode := SetErrorMode(SEM_FAILCRITICALERRORS);
    try
        if DiskSize(DrvNum - $40) <> -1 then
            result := true;
    finally
        SetErrorMode(EMode);
    end;
end;

function GetFullNodeName(Node: TTreeNode):string;
var
    CurNode : TTreeNode;
begin
    Result:=''; CurNode := Node;

    if Node.Parent = nil then result := Node.Text;

    while CurNode.Parent<>nil do
    begin
        Result:= CurNode.Text+'\'+Result;
        CurNode := CurNode.Parent;
        if CurNode.Parent = nil then begin result := CurNode.Text+Result; exit; end;
    end;
end;

function GetFullNodeNameEx(Node: TTreeNode):string;
var
    CurNode : TTreeNode;
    i: integer;
    t: string;
begin
    Result:=''; CurNode := Node;

    if Node.Parent = nil then result := Node.Text;

    while CurNode.Parent<>nil do
    begin
        Result:= CurNode.Text+'\'+Result;
        CurNode := CurNode.Parent;
        if CurNode.Parent = nil then begin result := CurNode.Text+Result; break; end;
    end;
    t:='';
    for i := 1 to length(result)-1 do
        t := t+result[i];
    Result := t;
end;

Procedure ShowSubDir(Dir:String; Node: TTreeNode);
Var
    SR        : TSearchRec;
    FindRes   : Integer;
    Root      : TTreeNode;
    CurNode   : TTreeNode;
begin
    FindRes:=FindFirst(Dir+'*.*',faAnyFile,SR);
    While FindRes=0 do
    begin
        if ((SR.Attr and faDirectory)=faDirectory) and
        ((SR.Name='.')or(SR.Name='..')) then
        begin
            FindRes:=FindNext(SR);
            Continue;
        end;
        if ((SR.Attr and faDirectory)=faDirectory) then
        begin
            CurNode := mainform.PathView.Items.AddChild(Node,SR.Name);
            mainform.PathView.Items.AddChild(CurNode,'');
            CurNode.ImageIndex    := 1;
            CurNode.SelectedIndex := 1;
            CurNode.StateIndex    := 1;
            FindRes:=FindNext(SR);
            Continue;
        end;
        FindRes:=FindNext(SR);
    end;
    FindClose(SR);
end;

Procedure ShowSubFiles(Dir:String; Node: TTreeNode);
Var
    SR        : TSearchRec;
    FindRes   : Integer;
    Root      : TTreeNode;
    CurNode   : TTreeNode;
begin
    FindRes:=FindFirst(Dir+'*.*',faAnyFile,SR);
    While FindRes=0 do
    begin
        if FileExists(Dir+SR.Name) then
        begin
            CurNode := mainform.PathView.Items.AddChild(Node,SR.Name);
            CurNode.ImageIndex    := 3;
            CurNode.SelectedIndex := 3;
            CurNode.StateIndex    := 3;
        end;
        FindRes:=FindNext(SR);
    end;
    FindClose(SR);
end;

Procedure ShowSub(Node: TTreeNode);
begin
    while Node.GetFirstChild<>nil do Node.GetFirstChild.Delete;
    ShowSubDir(GetFullNodeName(Node),Node);
    ShowSubFiles(GetFullNodeName(Node),Node);
    if node.Parent <> nil then begin
        node.SelectedIndex := 1;
        node.StateIndex := 1;
        node.ImageIndex := 1;
    end else begin
        node.SelectedIndex := 0;
        node.StateIndex := 0;
        node.ImageIndex := 0;
    end;
end;

procedure CreateDrivesList;
var
    Bufer : array[0..1024] of char;
    RealLen, i : integer;
    S : string;
    root : TTreeNode;
    img  : integer;
begin
    RealLen := GetLogicalDriveStrings(SizeOf(Bufer),Bufer);
    i := 0; S := '';
    while i < RealLen do begin
        if Bufer[i] <> #0 then begin
            S := S + Bufer[i];
            inc(i);
        end else begin
            inc(i);
            img := 0;
            case GetDriveType(PChar(S)) of
                DRIVE_REMOVABLE : img := 4;
                DRIVE_FIXED     : img := 0;
                DRIVE_CDROM     : img := 5;
            end;
            Root := mainform.PathView.Items.Add(nil,S);
            Root.SelectedIndex := img;
            Root.StateIndex    := img;
            Root.ImageIndex    := img;
            mainform.PathView.Items.AddChild(root,'');
            S := '';
        end;
    end;
end;
(* -------------------------------------------------------------------------- *)
procedure xc_debug (msg: dword; const args: array of const);
begin
    if msg = XC_UNARCH_FL then begin
        unarchfl := format('%s',args);
    end;

    case msg of

        XC_INIT_ERROR : begin
                            showmessage('xCore Initialization error.');
                            ExitProcess(0);
                        end;
    end;
end;

procedure xc_progress(progres: integer);
begin
    if progres < 0 then begin
        mainform.ScanProcess.Text := scanfile +' [-]';
    end
    else begin
        if unarchfl = '' then
            mainform.ScanProcess.Text := scanfile +' ['+ inttostr(progres)+'%]'
        else begin
            mainform.ScanProcess.Text := scanfile +'/'+ unarchfl +' ['+ inttostr(progres)+'%]'
        end;
    end;

    Application.ProcessMessages;
end;

Function ScanDir(Dir:String) : Boolean;
Var
    SR: TSearchRec;
    FindRes: Integer;
    vn: pchar;
    ret: integer;
begin
    Result := false;

    FindRes:=FindFirst(Dir+'*.*',faAnyFile,SR);
    While FindRes=0 do
    begin

        if stopped then exit;

        if ((SR.Attr and faDirectory)=faDirectory) and
        ((SR.Name='.')or(SR.Name='..')) then
        begin
            FindRes:=FindNext(SR);
            Continue;
        end;

        if ((SR.Attr and faDirectory)=faDirectory) then
        begin
            ScanDir(Dir+SR.Name+'\');
            FindRes:=FindNext(SR);
            Continue;
        end;

        if FileExists(Dir+SR.Name) then
        begin
            if stopped then exit;
            try
            scanfile := Dir + SR.Name;
            unarchfl := '';
            Application.ProcessMessages;
            inc(scanned);
            ret := xc_matchfile(engine, pchar(Dir+SR.Name), vn, xc_progress, xc_debug,true);
            if ret = XC_VIRUS then begin
                inc(infected);
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 3;
                    Caption := dir + SR.Name;
                    SubItems.Add(vn);
                end;
            end;
            if ret = XC_EREAD then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 0;
                    Caption := dir + SR.Name;
                    SubItems.Add('Ошибка чтения');
                end;
            end;
            if ret = XC_ESIZE then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 2;
                    Caption := dir + SR.Name;
                    SubItems.Add('Пропущен');
                end;
            end;
            if ret = XC_EMPTY then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 2;
                    Caption := dir + SR.Name;
                    SubItems.Add('Пустой (0 bytes)');
                end;
            end;
            except
            end;
        end;
        FindRes:=FindNext(SR);
    end;
    SysUtils.FindClose(SR);
    Result := true;
end;

Procedure ScanFileEx(path: string);
var
    ret: integer;
    vn: pchar;
begin
    if FileExists(path) then
    begin
        if stopped then exit;
        try
            scanfile := Path;
            unarchfl := '';
            Application.ProcessMessages;
            inc(scanned);
            ret := xc_matchfile(engine, pchar(path), vn, xc_progress, xc_debug,true);
            if ret = XC_VIRUS then begin
                inc(infected);
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 3;
                    Caption := path;
                    SubItems.Add(vn);
                end;
            end;
            if ret = XC_EREAD then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 0;
                    Caption := path;
                    SubItems.Add('Ошибка чтения');
                end;
            end;
            if ret = XC_ESIZE then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 2;
                    Caption := path;
                    SubItems.Add('Пропущен');
                end;
            end;
            if ret = XC_EMPTY then begin
                with mainform.ScanView.Items.Add do begin
                    ImageIndex := 2;
                    Caption := path;
                    SubItems.Add('Пустой (0 bytes)');
                end;
            end;
        except
        end;
    end;
end;

function MsToSec(ms: integer) : String;
var
    tmp: string;
begin
    tmp := inttostr(ms);
    if length(tmp) = 1 then begin
        Result := '0.00'+tmp;
        exit;
    end;
    if length(tmp) = 2 then begin
        Result := '0.0'+tmp;
        exit;
    end;
    if length(tmp) = 3 then begin
        Result := '0.'+tmp;
        exit;
    end;
    if length(tmp) >= 4 then begin
        Insert('.',tmp,length(tmp)-2);
        Result := tmp;
        exit;
    end;
end;
(* -------------------------------------------------------------------------- *)
{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
    CreateDrivesList;
    (* *)
    init_engine(engine, @xc_debug);
    xc_load_dbdir(engine,'database\', true);
    VersionLabel.Caption := xc_version;
    LoadedLabel.caption := inttostr(xc_sigcount(engine))+' записей';
    (* *)
end;

procedure TMainForm.PathViewExpanded(Sender: TObject; Node: TTreeNode);
begin
    if DiskInDrive(GetFullNodeName(Node)[1]) then
        ShowSub(Node)
    else Node.Expanded := false;

    if Node.Parent <> nil then
        if Node.ImageIndex <> 3 then
            if Node.Expanded then begin
                if Node.GetLastChild <> nil then begin
                    Node.ImageIndex := 2;
                    Node.SelectedIndex := 2;
                end;
            end else begin
                Node.ImageIndex := 1;
                Node.SelectedIndex := 1;
            end;
end;

procedure TMainForm.PathViewCollapsed(Sender: TObject; Node: TTreeNode);
begin
    if Node.Parent <> nil then
        if Node.ImageIndex <> 3 then
            if Node.Expanded then begin
                if Node.GetNext <> nil then begin
                    Node.ImageIndex := 2;
                    Node.SelectedIndex := 2;
                end;
            end else begin
                Node.ImageIndex := 1;
                Node.SelectedIndex := 1;
            end;
end;

procedure TMainForm.ScanBtnClick(Sender: TObject);
var
    te, ts: integer;
begin
    SelectPathTab.TabVisible := false;
    ScanProcessTab.TabVisible := true;
    ScanProcessTab.Show;
    (* *)
    if ClearResults.Checked then
        ScanView.Clear;
        
    stopped := false;
    StopBtn.Enabled := true;
    ScanBtn.Enabled := false;
    ts := GetTickCount;
    
    if DirectoryExists(path) then
        ScanDir(path)
    else
        ScanFileEx(path);

    te := GetTickCount;
    ScanProcess.Text := '';
    ScanBtn.Enabled := true;
    BackBtn.Enabled := true;
    StopBtn.Enabled := false;
    
    with ScanView.Items.Add do begin
        Caption := 'Файлов проверено';
        SubItems.Add(inttostr(scanned));
        ImageIndex := 1;
    end;
    with ScanView.Items.Add do begin
        Caption := 'Наидено объектов';
        SubItems.Add(inttostr(infected));
        ImageIndex := 1;
    end;
    with ScanView.Items.Add do begin
        Caption := 'Затрачено времени (мс)';
        SubItems.Add(mstosec(te-ts));
        ImageIndex := 1;
    end;
end;

procedure TMainForm.BackBtnClick(Sender: TObject);
begin
    SelectPathTab.TabVisible := true;
    ScanProcessTab.TabVisible := false;
    SelectPathTab.Show;
    BackBtn.Enabled := false;
end;

procedure TMainForm.StopBtnClick(Sender: TObject);
begin
    stopped := true;
end;

procedure TMainForm.CloseBtnClick(Sender: TObject);
begin
    free_engine(engine);
    Close;
end;

procedure TMainForm.PathViewChanging(Sender: TObject; Node: TTreeNode;
  var AllowChange: Boolean);
var
    pth: string;
begin
    pth := GetFullNodeNameEx(Node);
    if FileExists(pth) then
        path := GetFullNodeNameEx(Node)
    else
        path := GetFullNodeName(Node);
end;

end.
