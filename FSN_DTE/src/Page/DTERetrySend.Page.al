page 50006 "DTE Transaction Temp"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC Transaction Header";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    Caption = 'Pending Invoice Without Certification';

    layout
    {
        area(Content)
        {
            group(filters)
            {
                field(dateFilter; dateFilter)
                {
                    ApplicationArea = All;
                    Editable = true;
                    trigger OnValidate()
                    begin
                        loadTable(dateFilter);
                    end;
                }
            }
            repeater(Transactions)
            {
                editable = false;
                field("Receipt No."; "Receipt No.") { ApplicationArea = All; }
                field("Staff ID"; "Staff ID") { ApplicationArea = All; }
                field("Customer No."; "Customer No.") { ApplicationArea = All; }
                field(Payment; Payment) { ApplicationArea = All; }
                field(Date; Date) { ApplicationArea = All; }
                field("FSN Document Type"; "FSN Document Type") { ApplicationArea = All; }
                field("FSN NCF"; "FSN NCF") { ApplicationArea = All; }

            }
        }
    }
    actions
    {
        area(Processing)
        {
            action("CERTIFICAR DOCUMENTO")
            {
                Promoted = true;
                Caption = 'CERTIFICAR DOCUMENTO';
                PromotedIsBig = true;
                Image = PrintDocument;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    initialDate: Date;
                    ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
                    DTEHeader: Record "FSN DTE Transaction Header";
                    Parameter: Record "FSN Parameter";
                begin
                    Parameter.Reset();
                    Parameter.SetRange(Grupo, 'NOTPRINT');
                    Parameter.SetRange(Codigo, 'PAGEDTE');
                    IF (Parameter.FindFirst()) AND (Parameter.Activo) THEN
                        POSSESION.SetValue('PAGEDTE', 'TRUE');
                    if (Rec.Date = today) or (Rec.Date >= today - 5) then begin
                        initialDate := Rec.Date; //
                    end else begin
                        initialDate := CalcDate('<-CM>', Today());
                        if (date < initialDate) and (Date2DMY(date, 2) <> 10) then//remove second condition when complete month
                            Error(OUT_OF_RANGE);
                    end;
                    if (rec."Sale Is Return Sale") and (Rec."FSN Document Type" <> Rec."FSN Document Type"::"Nota Credito") then
                        ElectronicInvoiceTest.GenerateAndSendAnulation(Rec)
                    else
                        ElectronicInvoiceTest.GenerateAndSendInvoice(Rec);
                    POSSESION.SetValue('PAGEDTE', '');
                    if DTEHeader.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.") then
                        Rec.Delete();//wvillalta
                end;
            }

            action("CONTINGENCIA DTE")
            {
                Promoted = true;
                Caption = 'CONTINGENCIA';
                //PromotedIsBig = true;
                Image = PrevErrorMessage;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    initialDate: Date;
                    ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
                    DTEHeader: Record "FSN DTE Transaction Header";
                begin
                    POSSESION.SetValue('DTECONT', 'TRUE');
                    if (Rec.Date = today) or (Rec.Date >= today - 5) then begin
                        initialDate := Rec.Date; //
                    end else begin
                        initialDate := CalcDate('<-CM>', Today());
                        if (date < initialDate) and (Date2DMY(date, 2) <> 10) then//remove second condition when complete month
                            Error(OUT_OF_RANGE);
                    end;
                    if (rec."Sale Is Return Sale") and (Rec."FSN Document Type" <> Rec."FSN Document Type"::"Nota Credito") then
                        ElectronicInvoiceTest.GenerateAndSendAnulation(Rec)
                    else
                        ElectronicInvoiceTest.GenerateAndSendInvoice(Rec);
                    if DTEHeader.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.") then
                        Rec.Delete();//wvillalta
                end;
            }
            action("ViewLog")
            {
                Promoted = true;
                Caption = 'View Log';
                PromotedIsBig = true;
                Image = Select;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    msg: Text;
                    NOT_FOUND: Label 'No log found';
                    DEFAULT: Label 'Message: \%1';
                begin
                    //msg := MessageLog(Rec, dateFilter);
                    msg := ConSQl(Rec, dateFilter);
                    if msg = '' then
                        msg := NOT_FOUND;

                    if msg.Contains('\') then
                        msg := msg.Replace('\', '\n');

                    Message(StrSubstNo(DEFAULT, msg));
                end;
            }
            action("DTE")
            {
                Promoted = true;
                Caption = 'Cargar Sello';
                //PromotedIsBig = true;
                Image = ChangeBatch;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    msg: Text;
                    NOT_FOUND: Label 'No log found';
                    DEFAULT: Label 'Message: \%1';
                begin
                    //msg := MessageLog(Rec, dateFilter);
                    msg := ConSQlCont(Rec, dateFilter);
                    Message(StrSubstNo(DEFAULT, msg));
                    CurrPage.Update();
                end;
            }
            action("View Customer")
            {
                Promoted = true;
                Caption = 'View Customer';
                PromotedIsBig = true;
                Image = ViewCheck;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    customer: Record Customer;
                begin
                    customer.Reset();
                    customer.SetRange("No.", Rec."Customer No.");
                    Page.Run(50096, customer);
                end;
            }
            action("View Secondary Customer")
            {
                Promoted = true;
                Caption = 'View Secondary Customer';
                PromotedIsBig = true;
                Image = View;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    customer: Record Customer;
                    infocode: Record "LSC Trans. Infocode Entry";
                    subCustomer: Record Customer;
                begin
                    infocode.SetRange("Store No.", Rec."Store No.");
                    infocode.SetRange("POS Terminal No.", Rec."POS Terminal No.");
                    infocode.SetRange("Transaction No.", Rec."Transaction No.");
                    infocode.SetRange("Transaction Type", 0);
                    infocode.SetRange("Line No.", 40);
                    infocode.SetRange("Infocode", 'TEXT');
                    if not infocode.FindSet() then
                        exit;

                    if not subCustomer.Get(infocode.Information) then
                        exit;
                    customer.Reset();
                    customer.SetRange("No.", subCustomer."No.");
                    Page.Run(50096, customer);
                end;
            }
            action(Contingency)
            {
                Promoted = true;
                Caption = 'send to contingency';
                PromotedIsBig = true;
                Image = AuthorizeCreditCard;
                PromotedCategory = Process;
                ApplicationArea = All;
                Visible = false;

                trigger OnAction()
                var
                    ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
                    DTEHeader: Record "FSN DTE Transaction Header";
                begin
                    ElectronicInvoiceTest.SendWithContingency(Rec);
                    if DTEHeader.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.") then begin
                        Rec.Delete();
                        //TODO(): clear log
                    end;
                end;
            }
            action("CERTIFICAR All DOCUMENTO")
            {
                Promoted = true;
                Caption = 'CERTIFICAR TODOS DOCUMENTO';
                PromotedIsBig = true;
                Image = PrintDocument;
                PromotedCategory = Process;
                ApplicationArea = All;
                trigger OnAction()
                var
                    initialDate: Date;
                    ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
                    DTEHeader: Record "FSN DTE Transaction Header";
                begin
                    Rec.SetRange("Date", dateFilter);
                    if Rec.Find('-') then
                        repeat
                            POSSESION.SetValue('PAGEDTE', 'TRUE');
                            POSSESION.SetValue('DTEMESSAGE', 'TRUE');
                            /*if (Rec.Date = today) or (Rec.Date >= today - 5) then begin
                                initialDate := Rec.Date; //
                            end else begin
                                initialDate := CalcDate('<-CM>', Today());
                                if (date < initialDate) and (Date2DMY(date, 2) <> 10) then//remove second condition when complete month
                                    Error(OUT_OF_RANGE);
                            end;*/
                            if (rec."Sale Is Return Sale") and (Rec."FSN Document Type" <> Rec."FSN Document Type"::"Nota Credito") then
                                ElectronicInvoiceTest.GenerateAndSendAnulation(Rec)
                            else
                                ElectronicInvoiceTest.GenerateAndSendInvoice(Rec);
                            POSSESION.SetValue('PAGEDTE', '');
                            if DTEHeader.Get(Rec."Store No.", Rec."POS Terminal No.", Rec."Transaction No.") then
                                Rec.Delete();//wvillalta
                        until Rec.Next() = 0;
                    POSSESION.SetValue('DTEMESSAGE', '');
                end;
            }
        }
    }

    var
        OUT_OF_RANGE: Label 'Date out of range';
        dateFilter: Date;
        POSSESION: Codeunit "LSC POS Session";
        fsnParameter: Record "FSN Parameter";

    local procedure loadTable(date: Date)
    var
        transaction, transaction_tmp : Record "LSC Transaction Header";
        dte: Record "FSN DTE Transaction Header";
        dteRevert: Record "FSN DTE Transaction Header";
        session: Codeunit "LSC POS Session";
        ElectronicInvoiceTest: Codeunit "FSN Electronic Invoice";
        transRetreived: Record "LSC Transaction Header";
        NextStep: Boolean;
    begin
        Rec.DeleteAll();
        //? this calculate the initial date of current month
        if (session.StoreNo() <> '') then
            transaction.SetRange("Store No.", session.StoreNo());
        if (session.TerminalNo() <> '') then
            transaction.SetRange("POS Terminal No.", session.TerminalNo());
        transaction.SetRange("Date", date);
        transaction.SetFilter("Refund Receipt No.", '= %1', '');
        transaction.SetRange("Entry Status", 0);
        transaction.SetRange("Transaction Type", transaction."Transaction Type"::"Sales");
        transaction.SetFilter("FSN Document Type", '%1|%2|%3', transaction."FSN Document Type"::Factura, transaction."FSN Document Type"::"Nota Credito", transaction."FSN Document Type"::"Credito Fiscal");
        transaction.SetRange("FSN Fiscal Serie", '');
        if transaction.Find('-') then
            repeat
                NextStep := true;

                if (transaction."FSN Document Type" in [transaction."FSN Document Type"::"Credito Fiscal", transaction."FSN Document Type"::Factura]) and (transaction."Refund Receipt No." <> '') then
                    NextStep := false;

                transRetreived.Reset();
                transRetreived.SetRange("Receipt No.", transaction."Retrieved from Receipt No.");
                transRetreived.SetRange("Entry Status", 0);
                transRetreived.SetRange("Transaction Type", transRetreived."Transaction Type"::"Sales");
                if (transaction."FSN Document Type" = transaction."FSN Document Type"::"Nota Credito") then
                    if transRetreived.FindFirst() then
                        if transRetreived."FSN Fiscal Serie" <> '' then
                            NextStep := true
                        else
                            if not dteRevert.Get(transRetreived."Store No.", transRetreived."POS Terminal No.", transRetreived."Transaction No.") then
                                NextStep := false;

                dte.Reset();
                dte.SetRange("Store No.", transaction."Store No.");
                dte.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                dte.SetRange("Transaction No.", transaction."Transaction No.");
                if NextStep then
                    if not dte.FindFirst() then begin
                        Rec.Init();
                        Rec.TransferFields(transaction);
                        if Rec.Insert() then;
                    end else begin
                        if transaction."Sale Is Return Sale" and (transaction."FSN Document Type" <> transaction."FSN Document Type"::"Nota Credito") then begin
                            transaction_tmp.SetRange("Receipt No.", transaction."Retrieved from Receipt No.");
                            transaction_tmp.setRange("Store No.", transaction."Store No.");
                            transaction_tmp.setRange("POS Terminal No.", transaction."POS Terminal No.");
                            if transaction_tmp.FindFirst() then begin
                                dte.Reset();
                                dte.SetRange("Store No.", transaction."Store No.");
                                dte.SetRange("POS Terminal No.", transaction."POS Terminal No.");
                                dte.SetRange("Transaction No.", transaction."Transaction No.");
                                dte.SetRange("Status", dte.Status::Anulled);
                                if not dte.FindFirst() then begin
                                    Rec.Init();
                                    Rec.TransferFields(transaction);
                                    if Rec.Insert() then;
                                end;
                            end;
                        end
                    end;

            until transaction.Next() = 0;
    end;

    local procedure MessageLog(transaction: Record "LSC Transaction Header"; date: Date): Text;
    var
        streamReader: DotNet StreamReader;
        directory: DotNet Directory;
        localPath: Label 'D:\Soporte\DTE\';
        fileName: Text;
        jsonText, currentDate : Text;
        jObject: JsonObject;
        jToken: JsonToken;
    begin
        if not directory.Exists(localPath) then
            exit('');

        currentDate := Format(Today(), 0, '<Closing><Day,2>-<Month,2>-<Year>');

        fileName := localPath + currentDate + StrSubstNo('\%1_%2_%3_Response.json', transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.");

        if not File.Exists(fileName) then begin
            currentDate := Format(date, 0, '<Closing><Day,2>-<Month,2>-<Year>');

            fileName := localPath + currentDate + StrSubstNo('\%1_%2_%3_Response.json', transaction."Store No.", transaction."POS Terminal No.", transaction."Transaction No.");
        end;

        if not File.Exists(fileName) then
            exit('');


        streamReader := streamReader.StreamReader(fileName);

        jsonText := streamReader.ReadToEnd();

        jObject.ReadFrom(jsonText);

        if jObject.Get('body', jToken) then begin
            jObject := jToken.AsObject();
            if jObject.Get('statusMessage', jToken) then
                exit(jToken.AsValue().AsText());
        end;
    end;


    local procedure ConSQl(transaction: Record "LSC Transaction Header"; date: Date): Text;
    var
        myInt: Integer;
        PosTerminal: Record "LSC POS Terminal";
        SqlConnection: DotNet SqlConnection2;
        SqlCommand: DotNet SqlCommand2;
        SqlDataReader: DotNet SqlDataReader2;
        ConnectionString: Text[150];
        SqlString: Text;
        DisLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Message: Text;
        sala: code[20];
    begin
        if PosTerminal.Get(transaction."POS Terminal No.") then begin
            if getParams() then
                if fsnParameter."Distribution Location Ext." <> '' then
                    sala := fsnParameter."Distribution Location Ext."
                else
                    sala := transaction."Store No.";
            if DisLocation.GET(sala) then;
            ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", 'ElectronicInvoice', 'SA', 'Pa$$w0rd');
            SqlConnection :=
            SqlConnection.SqlConnection(ConnectionString);
            SqlString := 'SELECT  [ErrorMessage] FROM [ElectronicInvoice].[dbo].[ErrorMessageControl]where Id = (Select MAX([Id]) from [ElectronicInvoice].[dbo].[ErrorMessageControl] where [TransNumber] =''' + Format(transaction."Transaction No.") + '''  and [SellingPoint]=''' + DelChr(transaction."POS Terminal No.", '=', '#') + ''')';
            SqlConnection.Open();
            SqlCommand := SqlConnection.CreateCommand();
            SqlCommand.CommandText := SqlString;
            SqlDataReader := SqlCommand.ExecuteReader();
            IF SqlDataReader.Read() THEN begin
                Message := SqlDataReader.GetString(0);
            end;
            SqlConnection.Close();
            exit(Message);
        end;
    end;

    local procedure ConSQlCont(transaction: Record "LSC Transaction Header"; date: Date): Text;
    var
        list: List of [Text];
        PosTerminal: Record "LSC POS Terminal";
        SqlConnection: DotNet SqlConnection2;
        SqlCommand: DotNet SqlCommand2;
        SqlDataReader: DotNet SqlDataReader2;
        ConnectionString: Text[150];
        SqlString: Text;
        DisLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Message: Label 'Certificación Realizada!!!!';
        Error1: Label 'Factura Pendiente de certificar';
        seq: Text;
        dteTransaction: Record "FSN DTE Transaction Header";
        Exists: Boolean;
    begin
        if PosTerminal.Get(transaction."POS Terminal No.") then begin
            if DisLocation.GET(transaction."Store No.") then;
            ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", 'ElectronicInvoice', 'SA', 'Pa$$w0rd');
            SqlConnection :=
            SqlConnection.SqlConnection(ConnectionString);
            SqlString := 'SELECT *FROM [ElectronicInvoice].[dbo].[InvoiceDTO]where [IdShop]=''' + transaction."Store No." + ''' and [TransNo]=''' + Format(transaction."Transaction No.") + ''' and [SellingPoint]=''' + DelChr(transaction."POS Terminal No.", '=', '#') + ''' and [SelloRecepcion]<>''''';
            SqlConnection.Open();
            SqlCommand := SqlConnection.CreateCommand();
            SqlCommand.CommandText := SqlString;
            SqlDataReader := SqlCommand.ExecuteReader();
            if SqlDataReader.Read() then begin
                Exists := true;
                dteTransaction.Init();
                dteTransaction."DTE AuthNumber" := SqlDataReader.GetString(0);
                dteTransaction."DTE IssuedTimeStamp" := CopyStr(SqlDataReader.GetString(1), 1, 19);
                dteTransaction."DTE EnrolledTimeStamp" := CopyStr(SqlDataReader.GetString(2), 1, 19);
                dteTransaction."Document Type" := SqlDataReader.GetString(3);
                Evaluate(dteTransaction."Creating Date", SqlDataReader.GetString(5));
                seq := SqlDataReader.GetString(8);
                dteTransaction."DTE Invoice" := SqlDataReader.GetString(9);
                dteTransaction."Signature Validation" := SqlDataReader.GetString(13);
                dteTransaction."POS Terminal No." := transaction."POS Terminal No.";
                dteTransaction."Store No." := transaction."Store No.";
                dteTransaction."Transaction No." := transaction."Transaction No.";
                if dteTransaction.Insert(true) then;
                changeSequential(transaction, seq);
            end;

            SqlConnection.Close();
            if Exists then
                exit(Message)
            else
                exit(Error1);

        end;
    end;

    local procedure getParams(): Boolean;
    var
        posSession: Codeunit "LSC POS Session";
    begin
        fsnParameter.SetCurrentKey(Grupo, Codigo);
        fsnParameter.SetRange(Grupo, 'DTE_INVOICE');
        fsnParameter.SetRange(Codigo, Rec."POS Terminal No.");
        fsnParameter.SetRange(valor, 'WS');
        if not fsnParameter.FindFirst() then
            exit(false);

        exit(fsnParameter.Activo);
    end;

    local procedure changeSequential(var transaction: Record "LSC Transaction Header"; seq: Text)
    begin
        transaction."Legal Number" := seq;
        transaction."FSN NCF" := seq;
        transaction."FSN Correlative" := seq;

        if transaction.Modify(true) then;
    end;

    trigger OnOpenPage()
    begin
        POSSESION.SetValue('PAGEDTE', '');
        dateFilter := Today();
        loadTable(dateFilter);
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
    begin
        POSSESION.SetValue('PAGEDTE', '');
    end;
}