page 50099 Recetas
{
    ShowFilter = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    PageType = Card;
    PromotedActionCategories = 'Processing';
    layout
    {
        area(Content)
        {
            grid(Rece)
            {
                field(Receta; Receta)
                {
                    Editable = false;
                    Visible = not (Remision);
                    Style = Strong;
                    StyleExpr = 'Favorable';
                }
            }
            group(NuevoMedico)
            {
                Visible = NewMedic;
                Caption = '';
                grid(NewMed)
                {
                    field("Junta de médicos"; Junta)
                    {
                        HideValue = true;
                    }
                    field("No. Junta"; RegistroNo)
                    {
                        ApplicationArea = All;
                    }
                }
            }
            group(NombreoMedico)
            {
                Visible = NewMedic;
                Caption = '';
                grid(meNew)
                {
                    field(Nombre; NewMedicoN)
                    {
                        Editable = true;
                    }
                }
            }
            group(Prov)
            {
                Visible = NewMedic;
                Caption = '';
                grid(opc)
                {
                    field(Provicional; Provicional)
                    {
                        ApplicationArea = All;
                    }
                }
            }
            group(Registro)
            {
                Visible = not (NewMedic);
                Caption = '';
                grid(MyGrid)
                {
                    field("Registro No."; RegistroNo)
                    {
                        Editable = RecAdj;
                        trigger OnValidate()
                        var
                            myInt: Integer;
                        begin
                            getSQLInfo(RegistroNo);
                        end;
                    }
                    field(Junta; Junta)
                    {
                        Editable = RecAdj;
                    }
                }
            }
            group(Medic)
            {
                Visible = not (NewMedic);
                Caption = '';
                grid(med)
                {
                    field(Médico; Médico)
                    {
                        Editable = false;
                    }
                }
            }

            group(Info)
            {
                Caption = '';
                Visible = not (NewMedic);

                group("Tipo de receta")
                {
                    grid(rec)
                    {
                        field("Médico Sala"; MédicoSala)
                        {
                            Editable = RecAdj;
                            trigger OnValidate()
                            begin
                                if MédicoSala then
                                    MédicoExterno := false;
                            end;
                        }
                    }
                    grid(medi)
                    {
                        field("Médico Externo"; MédicoExterno)
                        {
                            ApplicationArea = All;
                            Editable = RecAdj;
                            trigger OnValidate()
                            begin
                                if MédicoExterno then
                                    MédicoSala := false;
                            end;
                        }
                    }
                }
                group(Seguimiento)
                {

                    grid(seg)
                    {
                        field("Tratamiento Continuo"; TratamientoContinuo)
                        {
                            Editable = RecAdj;
                        }
                    }
                }
            }
        }
        area(factboxes)
        {
            part(ItemPicture; "Fixed Asset Picture")
            {
                Editable = RecAdj;
                Caption = 'Receta';
                Visible = not (NewMedic);
            }
        }
    }
    actions
    {
        area(Processing)
        {

            action(ImportPicture)
            {

                Caption = 'Importar Receta';
                Image = Import;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Visible = not (NewMedi);
                trigger OnAction()
                var
                begin
                    if RecAdj then
                        InsertImagen();
                end;
            }
            action(NuevoM)
            {
                Caption = 'Nuevo Medico';
                Image = Import;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Visible = not (NewMedi);
                trigger OnAction()
                begin
                    NewMedi := true;
                    NewMedic := true;
                    RegistroNo := '';
                    CurrPage.Update(false);
                end;
            }
            action(Guardar)
            {
                Caption = 'Guardar Medico';
                Image = Save;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Visible = NewMedic;
                trigger OnAction()
                begin
                    NewDoctor();
                    NewMedic := false;
                    NewMedi := false;
                    "Médico" := NewMedicoN;
                    NewMedicoN := '';
                end;
            }
            action(Volver)
            {
                Caption = 'Volver';
                Image = Restore;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                Visible = NewMedic;
                trigger OnAction()
                begin
                    NewMedic := false;
                    NewMedi := false;
                    "Médico" := NewMedicoN;
                    NewMedicoN := '';
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        GetReceta();
        if not GetRecetas(ValidateRegisterR) then begin
            if FixedPicture.Get(GlobalPosTransaction."Receipt No.") then begin
                RegistroNo := FixedPicture."Global Dimension 1 Code";
                "Médico" := FixedPicture.Description;
                "MédicoSala" := FixedPicture.Comment;
                Registro := FixedPicture."Vendor No.";
                if FixedPicture."FA Class Code" <> Format(Junta) then
                    Junta := Junta::JVPO;
                TratamientoContinuo := FixedPicture."Budgeted Asset";
                if FixedPicture.Comment then
                    "MédicoSala" := true
                else
                    "MédicoExterno" := true;
            end else begin
                RegisterTable();
            end;
            RecetaReg;
        end;
        if FixedPicture.Get(GlobalPosTransaction."Receipt No.") then;
        CurrPage.ItemPicture.Page.SetRecord(FixedPicture);
        CurrPage.ItemPicture.Page.Update(false);
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        Messa01: Label 'Debe agregar un medico a la receta';
    begin
        if FixedPicture.Image.HasValue then begin
            if FixedPicture."Vendor No." = '' then begin
                if Médico = '' then begin
                    Message(Messa01);
                    EXIT(false);
                end;
            end;
        end;
    end;

    trigger OnClosePage()
    var
    begin
        if FixedPicture.Image.HasValue then begin
            Register();
            if FixedPicture.Get(GlobalPosTransaction."Receipt No.") then
                FixedPicture.Delete();
        end else begin
            FixedPicture.Delete();
            Message('NO HAY RECETA ADJUNTADA');
        end;
    end;

    var
        RegistroNo: Code[20];
        Registro: Text;
        RecAdj: Boolean;
        Imagenad: Text;
        Junta: Option JVPM,JVPO,JVPMV,JVPP;
        Médico: Text[100];
        FixedPicture: Record "Fixed Asset";
        MédicoExterno, MédicoSala : Boolean;
        Parametrosfsn: Record "FSN Parameter";
        TratamientoContinuo: Boolean;
        GlobalPosTransaction: Record "LSC POS Transaction";
        Receta: Text;
        NewMedic: Boolean;
        Provicional: Boolean;
        Remision: Boolean;
        NewMedicoN: Text[100];
        MostrarGrupo, NewMedi : Boolean;

    procedure GetReceta()
    var
        POSInfocode: Record "LSC POS Trans. Infocode Entry";
    begin
        POSInfocode.Reset();
        POSInfocode.SetRange("Store No.", GlobalPosTransaction."Store No.");
        POSInfocode.SetRange("POS Terminal No.", GlobalPosTransaction."POS Terminal No.");
        POSInfocode.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        POSInfocode.SetRange(Status, POSInfocode.Status::Processed);
        POSInfocode.SetFilter(Infocode, 'NRECETA|MEDICPRO');
        IF POSInfocode.Find('-') then
            repeat
                if Receta = '' then
                    Receta := POSInfocode.Information
                else
                    Receta += '| ' + POSInfocode.Information;
            until POSInfocode.Next() = 0;
    end;

    procedure ConfirReceta(RecordR: Text)
    var
        myInt: Integer;
    begin
        addLine(GlobalPosTransaction, RecordR);
    end;

    procedure addLine(
            transaction: Record "LSC POS Transaction";
            description: Text)
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Init();
        transLine.Validate("Receipt No.", transaction."Receipt No.");
        transLine.Validate("Store No.", transaction."Store No.");
        transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
        transLine.Validate("Line No.", getLine(transaction, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", 'Receta registrada con ID:  ' + description);
        transLine.Insert(true);
    end;

    local procedure RecetaReg()
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Reset();
        transLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        transLine.SetRange("POS Terminal No.", GlobalPosTransaction."POS Terminal No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
        transLine.SetRange("Entry Status", transLine."Entry Status"::" ");
        transLine.SetFilter(Description, '*Receta registrada con ID:*');
        if transLine.FindFirst() then
            RecAdj := false
        else
            RecAdj := true;
    end;

    local procedure getLine(transaction: Record "LSC POS Transaction"; type: text): Integer
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetCurrentKey("Receipt No.", "Line No.");
        transLine.SetRange("Receipt No.", transaction."Receipt No.");
        case type of
            'new':
                begin
                    if transLine.FindLast() then
                        exit(transLine."Line No." + 10000)
                    else
                        exit(10000);
                end;
        end;
    end;

    procedure GetPosTransaction(PosTransc: Record "LSC POS Transaction")
    var
        myInt: Integer;
    begin
        GlobalPosTransaction := PosTransc;
    end;

    local procedure getSQLInfo(RegistroNo: code[20])
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        Text0001: Label 'No se encontró al médico, agregue medico al registro!!!!';
    begin
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_getDoctorByNo ''' + RegistroNo + ''',''' + Format(Junta) + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then
                "Médico" := SqlDataReader.GetString(2)
            else
                "Médico" := '';
            sqlConnection.Close();
        end;
        if "Médico" = '' then begin
            Message(Text0001);
            NewMedic := true;
            NewMedi := true;
            RegistroNo := '';
            CurrPage.Update(false);
        end;
    end;

    local procedure GetRecetas(Recibo: code[20]): Boolean
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        Exis: Boolean;
    begin
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_obtenerDatosRecetas ''' + Recibo + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then begin
                MostrarGrupo := true;
                CamposVisibles();
                Exis := true;
                Registro := Format(SqlDataReader.GetInt32(0));
                Evaluate(Junta, SqlDataReader.GetString(2)); // Actualiza si es diferente
                RegistroNo := SqlDataReader.GetString(3);
                Imagenad := '\\192.168.0.204\recetas\' + SqlDataReader.GetString(7);
                if sqlDataReader.GetInt32(10) = 0 then
                    TratamientoContinuo := false
                else
                    TratamientoContinuo := true;
                sqlConnection.Close();
            end;
        end;
        if RegistroNo <> '' then begin
            getSQLInfo(RegistroNo);
            if not RecetaReg(GlobalPosTransaction) then
                ConfirReceta(Registro);
        end;

        if Imagenad <> '' then
            ImportImageFromNetworkPath(Imagenad);
        exit(Exis);
    end;


    local procedure RecetaReg(GlobalPosTransaction: Record "LSC POS Transaction"): Boolean
    var
        myInt: Integer;
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.Reset();
        transLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        transLine.SetRange("POS Terminal No.", GlobalPosTransaction."POS Terminal No.");
        transLine.SetRange("Entry Type", transLine."Entry Type"::FreeText);
        transLine.setrange("Entry Status", transLine."Entry Status"::" ");
        transLine.SetFilter(Description, '*Receta registrada con ID:*');
        exit(transLine.FindFirst());
    end;

    local procedure Register(): Text
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        STRTODAY_END: Text[20];
        TraTcon: Integer;
        ReceiptNo: Code[20];
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        F_Date: Text;
        F_Mes: Text;
        F_Dia: Text;
    begin
        STRTODAY_END := FORMAT(Date2DMY(Today, 3)) + '-' + FORMAT(Date2DMY(Today, 2)) + '-' + FORMAT(Date2DMY(Today, 1));
        if RecetaReg(GlobalPosTransaction) then begin
            exit('');
        end;
        if TratamientoContinuo then
            TraTcon := 1
        else
            TraTcon := 0;
        IF GlobalParametro then begin
            ReailUser.Get();
            query := 'EXEC sp_addrecipeHeader ''' + GlobalPosTransaction."Receipt No." + ''',''' + Format(Junta)
            + ''',''' + RegistroNo + ''',''' + GlobalPosTransaction."Store No." + ''',''' + STRTODAY_END + ''',''' + GlobalPosTransaction."Customer No." + ''','''
            + GlobalPosTransaction."Staff ID" + ''',''' + FixedPicture."Search Description" + ''',''' + Format(0) + ''',''' + Format(TraTcon) + ''',''' + Format(0) + ''',''' + Format(0) + ''',''' + Format(1) + '''';
            if distrLocation.Get(ReailUser."Local Store No.") then;
            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
            sqlConnection := sqlConnection.SqlConnection(con);

            sqlConnection.Open();
            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := query;
            SqlDataReader := sqlCommand.ExecuteReader();
            if SqlDataReader.Read() then
                ReceiptNo := Format(SqlDataReader.GetInt32(0));
            sqlConnection.Close();
            RegisterLine(ReceiptNo);
            ConfirReceta(ReceiptNo);
            exit(ReceiptNo);
        end;
    end;

    local procedure RegisterLine(ReceiptNo: Code[20])
    var
        query, con : Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        PosTransLine: Record "LSC POS Trans. Line";
        Item: Record Item;
    begin
        PosTransLine.Reset();
        PosTransLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.Find('-') then
            repeat
                Item.Reset();
                if Item.Get(PosTransLine.Number) then
                    if (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) or (Item."LSC Retail Product Code" in ['01002002', '01002001']) then
                        IF GlobalParametro then begin
                            ReailUser.Get();
                            query := 'EXEC sp_addRecipeLines ''' + ReceiptNo + ''',''' + GlobalPosTransaction."Receipt No." + ''',''' + PosTransLine.Number + ''',''' + PosTransLine."Unit of Measure" + ''',''' + Format(PosTransLine.Quantity) + '''';
                            if distrLocation.Get(ReailUser."Local Store No.") then;
                            con := StrSubstNo(lTextConn, distrLocation."DB Server Name", 'Prefactura', distrLocation."User ID", distrLocation.Password);
                            sqlConnection := sqlConnection.SqlConnection(con);
                            sqlConnection.Open();
                            sqlCommand := sqlConnection.CreateCommand();
                            sqlCommand.CommandText := query;
                            SqlDataReader := sqlCommand.ExecuteReader();
                            if SqlDataReader.Read() then;
                            sqlConnection.Close();
                        end
            until PosTransLine.Next() = 0;
    end;

    local procedure NewDoctor(): Boolean
    var
        con: Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        ResultMessage: Text;
        CodeResult: Integer;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false;User ID=%3;Password=%4;';
    begin
        if GlobalParametro then begin
            ReailUser.Get();
            if distrLocation.Get(ReailUser."Local Store No.") then;

            con := StrSubstNo(lTextConn,
                distrLocation."DB Server Name",
                'Prefactura',
                distrLocation."User ID",
                distrLocation.Password);

            sqlConnection := sqlConnection.SqlConnection(con);
            sqlConnection.Open();

            sqlCommand := sqlConnection.CreateCommand();
            sqlCommand.CommandText := 'sp_addNewDoctorValidate';
            sqlCommand.CommandType := 4; // Tipo StoredProcedure

            sqlCommand.Parameters.AddWithValue('@Junta', Junta);
            sqlCommand.Parameters.AddWithValue('@JVPM', RegistroNo);
            sqlCommand.Parameters.AddWithValue('@Name', NewMedicoN);
            sqlCommand.Parameters.AddWithValue('@CreateByPrefactura', 0);
            sqlCommand.Parameters.AddWithValue('@CodeResult', 00);
            sqlCommand.Parameters.AddWithValue('@ResultMessage', '');

            // Ejecutar y leer el mensaje devuelto
            sqlDataReader := sqlCommand.ExecuteReader();
            IF sqlDataReader.Read() THEN BEGIN
                CodeResult := sqlDataReader.GetInt32(0);
                ResultMessage := Format(sqlDataReader.GetValue(1));
            END;

            if CodeResult = 00 then
                Message(ResultMessage)
            else
                Error(ResultMessage);

            // Cerrar conexiones
            sqlDataReader.Close();
            sqlConnection.Close();
        end;
    end;

    local procedure GlobalParametro(): Boolean
    var
        myInt: Integer;
    begin
        Parametrosfsn.Reset();
        Parametrosfsn.SetRange(Grupo, 'ADJUNT');
        Parametrosfsn.SetRange(Codigo, 'RECETA');
        IF Parametrosfsn.FindFirst() then
            exit(Parametrosfsn.Activo);
    end;

    local procedure CamposVisibles()
    var
        myInt: Integer;
    begin
        if MostrarGrupo then begin
            NewMedic := false;
            NewMedi := true;
        end;
    end;

    local procedure InsertImagen()
    var
        FileMgt: Codeunit "File Management";
        InStr: InStream;
        FileName: Text;
        MediaSet: Record "Media Set";
        MediaResources: Record "Media Resources";
        TempFilePath: Text;
        SharedFolderPath: Text;
        DestFilePath: Text;
        FileExtension: Text;
        NewFileName: Text;
    begin
        if GlobalParametro() then begin
            SharedFolderPath := Parametrosfsn."Value Text 1";
            if UploadIntoStream('Seleccione archivo de receta', SharedFolderPath, '', FileName, InStr) then begin


                FileExtension := FileMgt.GetExtension(FileName);


                NewFileName := 'Receta_' + COPYSTR(UpperCase(CreateGuid()), 2, 36) + '.' + FileExtension;

                if not FixedPicture.Get(GlobalPosTransaction."Receipt No.") then
                    FixedPicture.Init();
                FixedPicture."No." := GlobalPosTransaction."Receipt No.";
                FixedPicture."Description 2" := 'Receta Médica';
                FixedPicture.Image.ImportStream(InStr, NewFileName);
                FixedPicture."Search Description" := NewFileName;
                //FixedPicture.Image.ImportStream(InStr, FileName);
                //FixedPicture."Search Description" := FileName;
                FixedPicture."Global Dimension 1 Code" := RegistroNo;
                FixedPicture.Description := "Médico";
                FixedPicture.Comment := "MédicoSala";
                FixedPicture."FA Class Code" := Format(Junta);
                FixedPicture."Budgeted Asset" := TratamientoContinuo;
                if not FixedPicture.Insert() then
                    FixedPicture.Modify();
                if FixedPicture.Get(GlobalPosTransaction."Receipt No.") then;
                CurrPage.ItemPicture.Page.SetRecord(FixedPicture);
                CurrPage.ItemPicture.Page.Update(false);
                CurrPage.Update(false);

                //TempFilePath := FileMgt.InstreamExportToServerFile(InStr, FileName);
                //DestFilePath := SharedFolderPath + FileName;
                TempFilePath := FileMgt.InstreamExportToServerFile(InStr, NewFileName);
                DestFilePath := SharedFolderPath + NewFileName;
                FileMgt.CopyServerFile(TempFilePath, DestFilePath, true);
                FileMgt.DeleteServerFile(TempFilePath);


                Message('La imagen de la receta ha sido importada correctamente.');
            end else
                Message('No se seleccionó ningún archivo.');
        end;
    end;

    local procedure RegisterTable()
    var
        myInt: Integer;
    begin
        if not FixedPicture.Get(GlobalPosTransaction."Receipt No.") then
            FixedPicture.Init();
        FixedPicture."No." := GlobalPosTransaction."Receipt No.";
        FixedPicture."Description 2" := 'Receta Médica';
        FixedPicture."Global Dimension 1 Code" := RegistroNo;
        FixedPicture.Description := "Médico";
        FixedPicture.Comment := "MédicoSala";
        FixedPicture."FA Class Code" := Format(Junta);
        FixedPicture."Budgeted Asset" := TratamientoContinuo;
        FixedPicture."Vendor No." := Registro;
        if not FixedPicture.Insert() then
            FixedPicture.Modify();
    end;

    local procedure ImportImageFromNetworkPath(FilePath: Text)
    var
        FileMgt: Codeunit "File Management";
        InStr: InStream;
        FileName: Text;
        TempBlob: Codeunit "Temp Blob";
    begin
        TempBlob.CreateInStream(InStr);
        FileMgt.BLOBImportFromServerFile(TempBlob, FilePath);
        FileName := FileMgt.GetFileName(FilePath);
        if not FixedPicture.Get(GlobalPosTransaction."Receipt No.") then
            FixedPicture.Init();
        FixedPicture."No." := GlobalPosTransaction."Receipt No.";
        FixedPicture."Description 2" := 'Receta Médica';
        FixedPicture.Image.ImportStream(InStr, FileName);
        FixedPicture."Global Dimension 1 Code" := RegistroNo;
        FixedPicture.Description := "Médico";
        FixedPicture.Comment := "MédicoSala";
        FixedPicture."FA Class Code" := Format(Junta);
        FixedPicture."Budgeted Asset" := TratamientoContinuo;
        FixedPicture."Vendor No." := Registro;
        if not FixedPicture.Insert() then
            FixedPicture.Modify();
    end;

    local procedure ValidateRegisterR(): Text;
    var
        myInt: Integer;
        PostrasLine: Record "LSC POS Trans. Line";
    begin
        PostrasLine.Reset();
        PostrasLine.SetRange("Receipt No.", GlobalPosTransaction."Receipt No.");
        PostrasLine.SetRange("Entry Status", PostrasLine."Entry Status"::" ");
        PostrasLine.SetFilter("FSN Remission No.", '<>%1', '');
        if PostrasLine.FindFirst() then begin
            Remision := true;
            exit(PostrasLine."FSN Remission No.");
        end
        else
            exit(GlobalPosTransaction."Receipt No.");
    end;
}