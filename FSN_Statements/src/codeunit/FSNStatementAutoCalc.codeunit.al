/// <summary>
/// Codeunit FSN Statement - Automatization (ID 50025).
/// </summary>
codeunit 50025 "FSN Statement - Automatization"
{
    trigger OnRun()
    begin

        case GlobalParametros() of
            '', 'TOTAL':
                begin
                    clearPostStatements();
                    calculateStatements();
                    postStatements();
                end;
            'CALC':
                begin
                    calculateStatements();
                end;
            'POST':
                begin
                    postStatementsJob();
                end;
            'POSTED':
                begin
                    postStatementsSTAT();
                end;
            'CLEAR':
                begin
                    ClearPostStatements();
                end;
            'DELETE':
                begin
                    DelStatements();
                end;
            'CHANGE':
                begin
                    Test();
                end;
            'AJUSTE':
                begin
                    AjusteStatement();
                end;
            'TEST':
                begin

                    //DuplicateRecib();
                end;
            'GLOBAL':
                begin
                    NewPrcesStatements();
                end;

        end;
    end;

    var
        FiltroFecha: Date;
        Sala: Code[20];
        mngLocST: Codeunit "Document Sub Type";
        Parameter: Record "FSN Parameter";
        Cantidad: Integer;
        cc: Codeunit 10001316;
        Statement: Record "LSC Statement";
        test1: Page "LSC Open Statement";
        rDocFace: Record "Legal Ledger Entry";
        LocalRegion: Code[20];
        Pa: Page 52;
        Codet: Codeunit 91;
        P: Page 6640;
        TimeLast: Time;

    local procedure DuplicateRecib(Statement: Record "LSC Statement")
    var
        myInt: Integer;
        TransSales: Record "LSC Trans. Sales Entry";
        Trans, Trans2 : Record "LSC Transaction Header";
        TransactionStatus: Record "LSC Transaction Status";
        Cont: Integer;
    begin
        TransactionStatus.Reset();
        TransactionStatus.SetCurrentKey("Statement No.");
        TransactionStatus.SetRange("Statement No.", Statement."No.");
        if TransactionStatus.Find('-') then begin
            repeat
                Trans.Reset();
                Trans.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                Trans.SetRange("Store No.", TransactionStatus."Store No.");
                Trans.SetRange("POS Terminal No.", TransactionStatus."POS Terminal No.");
                Trans.SetRange("Transaction No.", TransactionStatus."Transaction No.");
                Trans.SetRange("Transaction Type", Trans."Transaction Type"::Sales);
                if Trans.Find('-') then begin
                    Cont := 0;
                    Trans2.Reset();
                    Trans2.SetCurrentKey("Receipt No.");
                    Trans2.SetRange("Receipt No.", Trans."Receipt No.");
                    if Trans2.Find('-') then begin
                        repeat
                            Cont := Cont + 1;
                            if Cont = 2 then
                                Correccion(Trans);
                        until Trans2.Next() = 0;
                    end;
                end;
            until TransactionStatus.Next() = 0;
        end;
    end;

    local procedure CorreccionS(TransactionH: Record "LSC Transaction Header")
    var
        TSalesEntry: Record "LSC Trans. Sales Entry";
        TPaymeEntry: Record "LSC Trans. Payment Entry";
        POSCardEntry: Record "LSC POS Card Entry";
        TransInvento: Record "LSC Trans. Inventory Entry";
        TransIn_Exp: Record "LSC Trans. Inc./Exp. Entry";
        TransDiscon: Record "LSC Trans. Discount Entry";
        TransPointE: Record "LSC Trans. Point Entry";
        TransPointETemp: Record "LSC Trans. Point Entry" temporary;
        NewTransHeader: Record "LSC Transaction Header";
    begin
        TSalesEntry.Reset();
        TSalesEntry.SetRange("Store No.", TransactionH."Store No.");
        TSalesEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TSalesEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TSalesEntry.Find('-') then begin
            repeat
                TSalesEntry."Receipt No." := TSalesEntry."Receipt No." + 'X';
                TSalesEntry.Modify(true);
            until TSalesEntry.Next() = 0;
        end;

        TPaymeEntry.Reset();
        TPaymeEntry.SetRange("Store No.", TransactionH."Store No.");
        TPaymeEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TPaymeEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TPaymeEntry.Find('-') then begin
            repeat
                TPaymeEntry."Receipt No." := TPaymeEntry."Receipt No." + 'X';
                TPaymeEntry.Modify(true);
            until TPaymeEntry.Next() = 0;
        end;

        POSCardEntry.Reset();
        POSCardEntry.SetRange("Store No.", TransactionH."Store No.");
        POSCardEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        POSCardEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if POSCardEntry.Find('-') then begin
            repeat
                POSCardEntry."Receipt No." := POSCardEntry."Receipt No." + 'X';
                POSCardEntry.Modify(true);
            until POSCardEntry.Next() = 0;
        end;

        TransInvento.Reset();
        TransInvento.SetRange("Store No.", TransactionH."Store No.");
        TransInvento.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransInvento.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransInvento.Find('-') then begin
            repeat
                TransInvento."Receipt No." := TransInvento."Receipt No." + 'X';
                TransInvento.Modify(true);
            until TransInvento.Next() = 0;
        end;

        TransIn_Exp.Reset();
        TransIn_Exp.SetRange("Store No.", TransactionH."Store No.");
        TransIn_Exp.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransIn_Exp.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransIn_Exp.Find('-') then begin
            repeat
                TransIn_Exp."Receipt  No." := TransIn_Exp."Receipt  No." + 'X';
                TransIn_Exp.Modify(true);
            until TransIn_Exp.Next() = 0;
        end;

        TransDiscon.Reset();
        TransDiscon.SetRange("Store No.", TransactionH."Store No.");
        TransDiscon.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransDiscon.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransDiscon.Find('-') then begin
            repeat
                TransDiscon."Receipt No." := TransDiscon."Receipt No." + 'X';
                TransDiscon.Modify(true);
            until TransDiscon.Next() = 0;
        end;

        TransPointE.Reset();
        TransPointE.SetRange("Store No.", TransactionH."Store No.");
        TransPointE.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransPointE.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransPointE.Find('-') then begin
            repeat
                TransPointETemp := TransPointE;
                TransPointETemp."Receipt No." := TransPointE."Receipt No." + 'X';
                TransPointETemp.Insert();
            until TransPointE.Next() = 0;
        end;

        TransPointE.DELETEALL;
        TransPointETemp.RESET;
        IF TransPointETemp.FIND('-') THEN
            REPEAT
                TransPointE := TransPointETemp;
                TransPointE.INSERT;
            UNTIL TransPointETemp.NEXT = 0;

        NewTransHeader.Reset();
        NewTransHeader.SetRange("Store No.", TransactionH."Store No.");
        NewTransHeader.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        NewTransHeader.SetRange("Transaction No.", TransactionH."Transaction No.");
        if NewTransHeader.Find('-') then begin
            NewTransHeader."Receipt No." := NewTransHeader."Receipt No." + 'X';
            NewTransHeader.Modify(true);
        end;
    end;

    local procedure Correccion(TransactionH: Record "LSC Transaction Header")
    var
        TSalesEntry: Record "LSC Trans. Sales Entry";
        TPaymeEntry: Record "LSC Trans. Payment Entry";
        POSCardEntry: Record "LSC POS Card Entry";
        TransInvento: Record "LSC Trans. Inventory Entry";
        TransIn_Exp: Record "LSC Trans. Inc./Exp. Entry";
        TransDiscon: Record "LSC Trans. Discount Entry";
        TransPointE: Record "LSC Trans. Point Entry";
        TransPointETemp: Record "LSC Trans. Point Entry" temporary;
        NewTransHeader: Record "LSC Transaction Header";
        ReceiptBase: Code[20];
        Suffix: Text[1];
        Suffixes: array[4] of Text[1];
        i: Integer;
        NewReceiptNo: Code[20];
    begin
        Suffixes[1] := 'X';
        Suffixes[2] := 'Y';
        Suffixes[3] := 'Z';
        Suffixes[4] := 'C';

        // Obtener los primeros 19 caracteres del Receipt No.
        ReceiptBase := CopyStr(TransactionH."Receipt No.", 1, 19);

        // Buscar sufijo disponible
        Suffix := '';
        for i := 1 to 4 do begin
            NewReceiptNo := ReceiptBase + Suffixes[i];
            NewTransHeader.Reset();
            NewTransHeader.SetRange("Receipt No.", NewReceiptNo);
            if not NewTransHeader.FindFirst() then begin
                Suffix := Suffixes[i];
                break;
            end;
        end;
        if Suffix = '' then
            Suffix := Suffixes[4]; // Si todos existen, usar 'C'

        // Nuevo Receipt No.
        NewReceiptNo := ReceiptBase + Suffix;

        // Actualizar en todas las tablas relacionadas
        TSalesEntry.Reset();
        TSalesEntry.SetRange("Store No.", TransactionH."Store No.");
        TSalesEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TSalesEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TSalesEntry.Find('-') then
            repeat
                TSalesEntry."Receipt No." := NewReceiptNo;
                TSalesEntry.Modify(true);
            until TSalesEntry.Next() = 0;

        TPaymeEntry.Reset();
        TPaymeEntry.SetRange("Store No.", TransactionH."Store No.");
        TPaymeEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TPaymeEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TPaymeEntry.Find('-') then
            repeat
                TPaymeEntry."Receipt No." := NewReceiptNo;
                TPaymeEntry.Modify(true);
            until TPaymeEntry.Next() = 0;

        POSCardEntry.Reset();
        POSCardEntry.SetRange("Store No.", TransactionH."Store No.");
        POSCardEntry.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        POSCardEntry.SetRange("Transaction No.", TransactionH."Transaction No.");
        if POSCardEntry.Find('-') then
            repeat
                POSCardEntry."Receipt No." := NewReceiptNo;
                POSCardEntry.Modify(true);
            until POSCardEntry.Next() = 0;

        TransInvento.Reset();
        TransInvento.SetRange("Store No.", TransactionH."Store No.");
        TransInvento.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransInvento.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransInvento.Find('-') then
            repeat
                TransInvento."Receipt No." := NewReceiptNo;
                TransInvento.Modify(true);
            until TransInvento.Next() = 0;

        TransIn_Exp.Reset();
        TransIn_Exp.SetRange("Store No.", TransactionH."Store No.");
        TransIn_Exp.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransIn_Exp.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransIn_Exp.Find('-') then
            repeat
                TransIn_Exp."Receipt  No." := NewReceiptNo;
                TransIn_Exp.Modify(true);
            until TransIn_Exp.Next() = 0;

        TransDiscon.Reset();
        TransDiscon.SetRange("Store No.", TransactionH."Store No.");
        TransDiscon.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransDiscon.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransDiscon.Find('-') then
            repeat
                TransDiscon."Receipt No." := NewReceiptNo;
                TransDiscon.Modify(true);
            until TransDiscon.Next() = 0;

        TransPointE.Reset();
        TransPointE.SetRange("Store No.", TransactionH."Store No.");
        TransPointE.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        TransPointE.SetRange("Transaction No.", TransactionH."Transaction No.");
        if TransPointE.Find('-') then
            repeat
                TransPointETemp := TransPointE;
                TransPointETemp."Receipt No." := NewReceiptNo;
                TransPointETemp.Insert();
            until TransPointE.Next() = 0;

        TransPointE.DELETEALL;
        TransPointETemp.RESET;
        IF TransPointETemp.FIND('-') THEN
            REPEAT
                TransPointE := TransPointETemp;
                TransPointE.INSERT;
            UNTIL TransPointETemp.NEXT = 0;

        NewTransHeader.Reset();
        NewTransHeader.SetRange("Store No.", TransactionH."Store No.");
        NewTransHeader.SetRange("POS Terminal No.", TransactionH."POS Terminal No.");
        NewTransHeader.SetRange("Transaction No.", TransactionH."Transaction No.");
        if NewTransHeader.Find('-') then begin
            NewTransHeader."Receipt No." := NewReceiptNo;
            NewTransHeader.Modify(true);
        end;
    end;

    local procedure Test()
    var
        myInt: Integer;
        Trans: Record "LSC Transaction Header";
        TransactionStatus: Record "LSC Transaction Status";
    begin
        Trans.Reset();
        Trans.SetRange(Date, FiltroFecha);
        Trans.SetRange("Store No.", Sala);
        Trans.SetFilter("Posted Statement No.", '=%1', '');
        Trans.SetFilter("Statement No.", '<>%1', '');
        if Trans.Find('-') then begin
            repeat
                if TransactionStatus.Get(Trans."Store No.", Trans."POS Terminal No.", Trans."Transaction No.") then begin
                    if TransactionStatus."Posted Statement No." = '' then
                        TransactionStatus.Delete();
                end;
            until Trans.Next() = 0;
        end;
    end;

    local procedure NewPrcesStatements()
    var
        store: Record "LSC Store";
        statement, statementpostr, statementcal, DifStatement : Record "LSC Statement";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        BatchPosting: Codeunit "LSC Batch Posting";
        statementPost: Codeunit "FSN Statement - Post";
        Tlast: Time;
        Tini: Time;
    begin
        Tlast := 000001T;
        Tini := 040000T;

        statement.SetCurrentKey("Trans. Starting Date");
        IF (Time >= Tini) AND (Time <= Tlast) then
            statement.SetRange("Trans. Starting Date", 0D, Today() - 1)
        ELSE
            statement.SetRange("Trans. Starting Date", 0D, Today());
        statement.SetAscending("Trans. Starting Date", true);
        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                //Limpiar declaraciones
                Commit();
                IF statement."Calculated Date" <> 0D then
                    ClearStatment(statement);
                //Calcular declaraciones
                Commit();

                Clear(StatementCalculate);
                statementcal.SetRange("Store No.", statement."Store No.");
                statementcal.SetRange("No.", statement."No.");
                if statementcal.FindFirst() then;
                if BatchPosting.GetStatementStatus(statementcal) < 0 then begin
                    statementcal."Skip Confirmation" := true;
                    if StatementCalculate.Run(statementcal) then;
                    Commit();
                    //Validar declaraciones con diferencias
                    DifStatement.SetRange("Store No.", statement."Store No.");
                    DifStatement.SetRange("No.", statement."No.");
                    if DifStatement.FindFirst() then;
                    if not ValidateStatments(DifStatement) then begin
                        //Limpiar declaraciones
                        ClearCalc(DifStatement);
                    end;
                    //Registrar declaraciones
                    DuplicateRecib(DifStatement);
                    //Postear declaraciones
                    Commit();
                    statementpostr.SetRange("Store No.", statement."Store No.");
                    statementpostr.SetRange("No.", statement."No.");
                    if statementpostr.FindFirst() then begin
                        if BatchPosting.GetStatementStatus(statementpostr) < 0 then
                            if not statementpostr.Recalculate then begin
                                if statementPost.SafeManagementCheck(statementpostr) then begin
                                    Clear(statementPost);
                                    statementpostr.CalcFields("Serial/Lot No. Not Valid");
                                    if statementpostr."Serial/Lot No. Not Valid" <= 0 then begin
                                        if ValidateStatments(statementpostr) then
                                            if Store.Get(statementpostr."Store No.") then begin
                                                if not Store."Use Batch Posting for Statem." then begin

                                                    IF statementPost.Run(statementpostr) then;
                                                    //IF Codeunit.Run(Codeunit::"FSN Statement - Post", statement) THEN;
                                                end else
                                                    BatchPosting.ValidateAndPostStatement(statementpostr, false);
                                                Clear(StatementPost);
                                                Clear(BatchPosting);
                                            end;
                                    end;
                                end;
                            end;
                    end;
                    //Cambio en cofre
                    if Store.Get(statement."Store No.") then begin
                        Store."Safe Mgnt. in Use" := true;
                        Store.Modify(true);
                        Commit();
                    end;
                end;
            until statement.Next() = 0;
    end;

    procedure AjusteStatement()
    var
        myInt: Integer;
    begin
        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');

        if Format(FiltroFecha) <> '' then
            statement.SetRange("Date Filter", FiltroFecha)
        else begin
            statement.SetCurrentKey("Trans. Starting Date");
            statement.SetRange("Trans. Starting Date", 0D, Today() - 1);
            statement.SetAscending("Trans. Starting Date", true);
        end;
        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then begin
            repeat
                if ValidateAj(statement) then;
            until Statement.Next() = 0;
        end;
    end;

    local procedure ClearPostStatements()
    var
        statement: Record "LSC Statement";
        store: Record "LSC Store";
        statementPost: Codeunit "FSN Statement - Post";
        t: Codeunit "LSC Statement-Post";
        batchPosting: Codeunit "LSC Batch Posting";
        ExplanationMsg: Text;
        StatementCalculate: Codeunit "LSC Statement-Calculate";
    begin

        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');

        if Format(FiltroFecha) <> '' then
            statement.SetRange("Trans. Ending Date", FiltroFecha)
        else
            statement.SetRange("Trans. Ending Date", Today());

        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                statement.CalcFields("Serial/Lot No. Not Valid");
                //if not ValidateStatments(statement) then
                if BatchPosting.GetStatementStatus(statement) < 0 then
                    if statement."Serial/Lot No. Not Valid" <= 0 then begin
                        StatementCalculate.SetTransactionsFree(statement);
                        statement.Recalculate := false;
                        statement.Modify;
                    end;
            until statement.Next() = 0;
    end;

    procedure ClearStatment(Stm: record "LSC Statement")
    var
        statement: Record "LSC Statement";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        batchPosting: Codeunit "LSC Batch Posting";
    begin
        if statement.Get(Stm."Store No.", Stm."No.") then begin
            statement.CalcFields("Serial/Lot No. Not Valid");
            if BatchPosting.GetStatementStatus(statement) < 0 then
                if statement."Serial/Lot No. Not Valid" <= 0 then begin
                    StatementCalculate.SetTransactionsFree(statement);
                    statement.Recalculate := false;
                    statement.Modify;
                    Commit();
                end;
        end;
    end;

    local procedure DelStatements()
    var
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        statement: Record "LSC Statement";
    begin
        if statement.FindSet() then
            repeat
                StatementCalculate.SetTransactionsFree(statement);
                statement.Delete(true);
            until statement.Next() = 0;
    end;

    local procedure Stat()
    var
        statement: Record "LSC Statement";
        store: Record "LSC Store";
        statementPost: Codeunit "FSN Statement - Post";
        batchPosting: Codeunit "LSC Batch Posting";
        Sta: Codeunit "LSC Statement-Post";
        i: Integer;
    begin
        statement.SetCurrentKey("Store No.");
        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');
        if Format(FiltroFecha) <> '' then
            statement.SetRange("Trans. Starting Date", FiltroFecha);

        if Cantidad = 0 then
            Cantidad := 15;

        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                DuplicateRecib(statement);
            until statement.Next() = 0;
    end;

    local procedure postStatements()
    var
        statement: Record "LSC Statement";
        store: Record "LSC Store";
        statementPost: Codeunit "FSN Statement - Post";
        batchPosting: Codeunit "LSC Batch Posting";
        Sta: Codeunit "LSC Statement-Post";
        i: Integer;
        IsSuccess: Boolean;
    begin
        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');
        if Format(FiltroFecha) <> '' then
            statement.SetRange("Trans. Starting Date", FiltroFecha)
        else begin
            statement.SetCurrentKey("Trans. Starting Date");
            statement.SetRange("Trans. Starting Date", 0D, Today());
            statement.SetAscending("Trans. Starting Date", true);
        end;


        if Cantidad = 0 then
            Cantidad := 15;

        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                if BatchPosting.GetStatementStatus(statement) < 0 then
                    if not statement.Recalculate then begin
                        if statementPost.SafeManagementCheck(statement) then begin
                            Clear(statementPost);
                            statement.CalcFields("Serial/Lot No. Not Valid");
                            if statement."Serial/Lot No. Not Valid" <= 0 then begin
                                if ValidateStatments(statement) then
                                    if Store.Get(statement."Store No.") then begin
                                        if not Store."Use Batch Posting for Statem." then begin
                                            i := i + 1;
                                            //StatementPost.Run(statement);
                                            // IsSuccess := StatementPost.Run(statement);
                                            IF Codeunit.Run(Codeunit::"FSN Statement - Post", statement) THEN;
                                        end else
                                            BatchPosting.ValidateAndPostStatement(statement, false);

                                        Clear(StatementPost);
                                        Clear(BatchPosting);
                                        if i = Cantidad then
                                            exit;

                                        if TimeLast <> 0T then
                                            if TimeLast <= Time then
                                                exit; // Exit if the last time is less than or equal to the current time
                                    end;
                            end;
                        end;
                    end;
            until statement.Next() = 0;
    end;

    local procedure postStatementsJob()
    var
        statement: Record "LSC Statement";
        store: Record "LSC Store";
        statementPost: Codeunit "FSN Statement - Post";
        batchPosting: Codeunit "LSC Batch Posting";
        Sta: Codeunit "LSC Statement-Post";
        i: Integer;
        Stat: Boolean;
    begin
        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');
        if Format(FiltroFecha) <> '' then
            statement.SetRange("Trans. Starting Date", FiltroFecha)
        else begin
            statement.SetCurrentKey("Trans. Starting Date");
            statement.SetRange("Trans. Starting Date", 0D, Today());
            statement.SetAscending("Trans. Starting Date", true);
        end;

        if Cantidad = 0 then
            Cantidad := 15;

        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                DuplicateRecib(statement);
                if BatchPosting.GetStatementStatus(statement) < 0 then
                    if not statement.Recalculate then begin
                        if statementPost.SafeManagementCheck(statement) then begin
                            Clear(statementPost);
                            statement.CalcFields("Serial/Lot No. Not Valid");
                            if statement."Serial/Lot No. Not Valid" <= 0 then begin
                                if ValidateStatments(statement) then
                                    if Store.Get(statement."Store No.") then begin
                                        if not Store."Use Batch Posting for Statem." then begin
                                            i := i + 1;
                                            statementPost.Run(statement);
                                            //IF Codeunit.Run(Codeunit::"FSN Statement - Post", statement) THEN;
                                        end else
                                            BatchPosting.ValidateAndPostStatement(statement, false);

                                        Clear(StatementPost);
                                        Clear(BatchPosting);
                                        if i = Cantidad then
                                            exit;
                                        if TimeLast <> 0T then
                                            if TimeLast <= Time then
                                                exit;
                                    end;
                            end;
                        end;
                    end;
            until statement.Next() = 0;
    end;

    local procedure postStatementsSTAT()
    var
        statement, statementPR : Record "LSC Statement";
        store: Record "LSC Store";
        statementPost: Codeunit "FSN Statement - Post";
        batchPosting: Codeunit "LSC Batch Posting";
        Sta: Codeunit "LSC Statement-Post";
        i: Integer;
        Stat: Boolean;
    begin
        if Sala <> '' then
            statement.SetRange("Store No.", Sala)
        else
            statement.SetFilter("Store No.", '<>%1', '');
        if Format(FiltroFecha) <> '' then
            statement.SetRange("Trans. Starting Date", FiltroFecha)
        else begin
            statement.SetCurrentKey("Trans. Starting Date");
            statement.SetRange("Trans. Starting Date", 0D, Today());
            statement.SetAscending("Trans. Starting Date", true);
        end;

        if Cantidad = 0 then
            Cantidad := 15;
        Commit();
        statement.SetRange(Status, statement.Status::" ");
        if statement.FindSet() then
            repeat
                DuplicateRecib(statement);
                Commit();
                statementPR.Reset();
                statementPR.SetRange("Store No.", statement."Store No.");
                statementPR.SetRange("No.", statement."No.");
                if statementPR.FindFirst() then
                    if BatchPosting.GetStatementStatus(statementPR) < 0 then
                        if not statementPR.Recalculate then begin
                            if statementPost.SafeManagementCheck(statementPR) then begin
                                Clear(statementPost);
                                statementPR.CalcFields("Serial/Lot No. Not Valid");
                                if statementPR."Serial/Lot No. Not Valid" <= 0 then begin
                                    if ValidateStatments(statementPR) then
                                        if Store.Get(statementPR."Store No.") then begin
                                            if not Store."Use Batch Posting for Statem." then begin
                                                i := i + 1;
                                                if statementPost.Run(statementPR) then;
                                            end else
                                                BatchPosting.ValidateAndPostStatement(statementPR, false);

                                            Clear(StatementPost);
                                            Clear(BatchPosting);
                                            if i = Cantidad then
                                                exit;
                                            if TimeLast <> 0T then
                                                if TimeLast <= Time then
                                                    exit;
                                        end;
                                end;
                            end;
                        end;
            until statement.Next() = 0;
    end;

    local procedure ValidateStatments(Stmt_p: Record "LSC Statement"): Boolean
    var
        myInt: Integer;
        StatementLine_l: Record "LSC Statement Line";
        TotDiff, TotCounted : Decimal;
        CountedAmtChecked, RunningFromBatchPosting_p : Boolean;
    begin
        TotDiff := 0;
        TotCounted := 0;

        StatementLine_l.RESET;
        StatementLine_l.SETRANGE("Statement No.", Stmt_p."No.");
        StatementLine_l.CalcSums("Difference Amount");
        TotDiff := StatementLine_l."Difference Amount";

        IF TotDiff <> 0 THEN //387.02
            exit(false)
        else
            exit(true);
    end;

    local procedure ValidateAj(Stmt_p: Record "LSC Statement"): Boolean
    var
        myInt: Integer;
        StatementLine_l: Record "LSC Statement Line";
        TotDiff, TotCounted : Decimal;
        CountedAmtChecked, RunningFromBatchPosting_p : Boolean;
    begin
        TotDiff := 0;
        TotCounted := 0;

        StatementLine_l.RESET;
        StatementLine_l.SETRANGE("Statement No.", Stmt_p."No.");

        StatementLine_l.CalcSums("Difference Amount");
        TotDiff := StatementLine_l."Difference Amount";

        IF TotDiff <> 0 THEN //387.02
            ClearCalc(Stmt_p);
        exit(true);
    end;


    procedure ClearCalc(Stmt_p: Record "LSC Statement")
    var
        myInt: Integer;
        StatementLine_l: Record "LSC Statement Line";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        Store: Record "LSC Store";
    begin
        if Store.Get(Stmt_p."Store No.") then begin
            Store."Safe Mgnt. in Use" := false;
            Store.Modify(true);
            Commit();
        end;
        StatementCalculate.SetTransactionsFree(Stmt_p);
        CalNew(Stmt_p);
        StatementLine_l.RESET;
        StatementLine_l.SETRANGE("Statement No.", Stmt_p."No.");
        StatementLine_l.SetFilter("Difference Amount", '<>%1', 0.0);
        if StatementLine_l.Find('-') then begin
            repeat
                StatementLine_l.Validate("Counted Amount", StatementLine_l."Trans. Amount");
                StatementLine_l.Modify(true);
                Commit();
            until StatementLine_l.Next() = 0;
        end;
    end;

    procedure CalNew(statement_n: Record "LSC Statement")
    var
        myInt: Integer;
        statement: Record "LSC Statement";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        BatchPosting: Codeunit "LSC Batch Posting";
    begin
        statement.SetRange("Store No.", statement_n."Store No.");
        statement.SetRange("No.", statement_n."No.");
        if statement.Find('-') then
            repeat
                Clear(StatementCalculate);
                statement."Skip Confirmation" := true;
                if BatchPosting.GetStatementStatus(statement) < 0 then begin
                    StatementCalculate.Run(statement);
                end;
                Commit();
            until statement.Next() = 0;
    end;

    local procedure calculateStatements()
    var
        store: Record "LSC Store";
        statement: Record "LSC Statement";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        BatchPosting: Codeunit "LSC Batch Posting";
    begin

        store.Reset();
        if Sala <> '' then
            store.SetRange("No.", Sala);
        if store.Find('-') then
            repeat
                if store."Closing Method" <> store."Closing Method"::Shift then
                    prepareStatements(store);
            until store.Next() = 0;

        Commit();

        Clear(statement);
        store.Reset();
        if Sala <> '' then
            store.SetRange("No.", Sala);
        store.SetRange("Auto. Calculate Statement", true);
        if store.Find('-') then
            repeat
                statement.SetRange("Store No.", store."No.");
                //statement.SetRange("Skip Confirmation", false);
                if Format(FiltroFecha) <> '' then
                    statement.SetRange("Trans. Starting Date", FiltroFecha);
                if statement.Find('-') then
                    repeat
                        Clear(StatementCalculate);
                        statement."Skip Confirmation" := true;
                        if BatchPosting.GetStatementStatus(statement) < 0 then
                            if StatementCalculate.Run(statement) then;
                    until statement.Next() = 0;
            until store.Next() = 0;
    end;

    local procedure calculateStatement()
    var
        store: Record "LSC Store";
        statement: Record "LSC Statement";
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        BatchPosting: Codeunit "LSC Batch Posting";
    begin

        Clear(statement);
        store.Reset();
        if Sala <> '' then
            store.SetRange("No.", Sala);
        store.SetRange("Auto. Calculate Statement", true);
        if store.Find('-') then
            repeat
                statement.SetRange("Store No.", store."No.");
                //statement.SetRange("Skip Confirmation", false);
                if Format(FiltroFecha) <> '' then
                    statement.SetFilter("Trans. Starting Date", '>=%1', FiltroFecha);
                if statement.Find('-') then
                    repeat
                        Clear(StatementCalculate);
                        statement."Skip Confirmation" := true;
                        if BatchPosting.GetStatementStatus(statement) < 0 then
                            if StatementCalculate.Run(statement) then;
                    until statement.Next() = 0;
            until store.Next() = 0;
    end;

    local procedure prepareStatements(store: Record "LSC Store")
    var
        template, statement : Record "LSC Statement";
        transaction, transactionfD : Record "LSC Transaction Header";
        terminal: Record "LSC POS Terminal" temporary;
        isCreate: Boolean;
        ok: Boolean;
        PosTerminal: Record "LSC POS Terminal";
        fsnParam: Record "FSN Parameter";
        Tfinal: Time;
        Tini: Time;
    begin
        Tini := 060000T;
        Tfinal := 230000T;
        ok := true;
        template.Init();
        template."Store No." := store."No.";
        if setDatesInStatement(template, store) then begin
            while template."Trans. Starting Date" <= template."Trans. Ending Date" do begin
                fsnParam.Reset();
                fsnParam.SetRange(Grupo, 'DECLARACION');
                fsnParam.SetRange(Codigo, 'TERMINAL');
                fsnParam.SetRange(Activo, true);
                if fsnParam.FindSet() then
                    IF (Time >= Tini) AND (Time <= Tfinal) then begin
                        PosTerminal.Reset();
                        PosTerminal.SetRange("Store No.", store."No.");
                        if PosTerminal.Find('-') then
                            repeat
                                transactionfD.Reset();
                                transactionfD.SetRange("Store No.", store."No.");
                                transactionfD.SetRange(Date, template."Trans. Starting Date");
                                transactionfD.SetRange("Transaction Type", transactionfD."Transaction Type"::"Tender Decl.");
                                transactionfD.SetRange("POS Terminal No.", PosTerminal."No.");
                                if transactionfD.Find('-') then begin
                                    ok := true
                                end else begin
                                    transactionfD.Reset();
                                    transactionfD.SetRange("Store No.", store."No.");
                                    transactionfD.SetRange(Date, template."Trans. Starting Date");
                                    transactionfD.SetRange("POS Terminal No.", PosTerminal."No.");
                                    if transactionfD.Find('+') then begin
                                        if not (transactionfD."Transaction Type" = transactionfD."Transaction Type"::"Tender Decl.") then
                                            ok := false
                                    end;
                                end;
                            until (PosTerminal.Next() = 0) OR not (ok);
                    end;
                if ok then begin
                    transaction.Reset();
                    transaction.SetAutoCalcFields("Statement No.");
                    if store."Closing Method" = store."Closing Method"::"Date and Time" then begin
                        transaction.SetCurrentKey("Store No.", Date);
                        transaction.SetRange("Store No.", template."Store No.");
                        transaction.SetRange("Date", template."Trans. Starting Date", template."Trans. Starting Date");
                        transaction.SetFilter("Transaction Type", '<>%1&<>%2&<>%3&<>%4', transaction."Transaction Type"::PhysInv, transaction."Transaction Type"::Logon, transaction."Transaction Type"::Logoff, transaction."Transaction Type"::"Open Drawer");
                    end;
                    transaction.SetRange("Entry Status", transaction."Entry Status"::" ");
                    if (not Store."Group by Staff/POS") or (Store."Statement Method" = Store."Statement Method"::Total) then begin
                        isCreate := false;
                        template."Staff/POS Term Filter Internal" := '';
                        if transaction.FindSet() then
                            repeat
                                if transaction."Statement No." = '' then
                                    isCreate := true;
                            until (transaction.Next() = 0) or IsCreate;
                        if isCreate then begin
                            statement.Init();
                            statement := template;
                            statement."Trans. Ending Date" := statement."Trans. Starting Date";
                            statement."Posting Date" := statement."Trans. Starting Date";
                            CreateStatements(Statement, Store);
                        end;
                    end;
                end;
                template."Trans. Starting Date" += 1;
            end;
        end;
    end;

    local procedure CreateStatements(Statement: Record "LSC Statement"; Store: Record "LSC Store")
    var
        statementCheck: Record "LSC Statement";
        NoSeriesMgt: Codeunit NoSeriesManagement;
    begin
        statementCheck.SetRange("Store No.", Store."No.");
        if store."Closing Method" = store."Closing Method"::"Date and Time" then begin
            if (Statement."Trans. Starting Date" = 0D) or (Statement."Trans. Ending Date" = 0D) then
                exit;
            StatementCheck.SetRange("Trans. Starting Date", Statement."Trans. Starting Date");
            StatementCheck.SetRange("Trans. Ending Date", Statement."Trans. Ending Date");
            StatementCheck.SetRange("Trans. Starting Time", 0T);
            StatementCheck.SetRange("Trans. Ending Time", 0T);
        end;
        StatementCheck.SetRange("Staff/POS Term Filter Internal", Statement."Staff/POS Term Filter Internal");
        if StatementCheck.IsEmpty() then begin
            Statement."No." := '';
            Statement.CalcFields("Store Name");
            NoSeriesMgt.InitSeries(Store."Statement Nos.", Statement."No. Series", 0D, Statement."No.",
                    Statement."No. Series");
            if (Statement."No. Series" <> '') and (Store."Posted Statem. Nos." = Store."Statement Nos.") then
                Statement."Posting No. Series" := Statement."No. Series"
            else
                NoSeriesMgt.SetDefaultSeries(Statement."Posting No. Series", Store."Posted Statem. Nos.");
            Statement."Store No." := Store."No.";
            Statement.Method := Store."Statement Method";
            Statement."Closing Method" := Store."Closing Method";
            Statement.Insert(true);
        end;
    end;

    /*local procedure setDatesInStatement(var statement: Record "LSC Statement"; store: Record "LSC Store"): Boolean
    var
        transactionStatus: Record "LSC Transaction Status";
        transaction: Record "LSC Transaction Header";
    begin
        statement."Trans. Ending Date" := Today() - 1;

        transaction.SetCurrentKey("Store No.", Date);
        transaction.SetRange("Store No.", store."No.");
        transaction.SetFilter(Date, '>=%1', CalcDate('-30D', Today));
        if transaction.Find('-') then
            statement."Trans. Starting Date" := transaction.Date
        else
            exit(false);

        statement."Posting Date" := Today();

        exit(true);


        transactionStatus.SetCurrentKey(Date);
        transactionStatus.SetRange("Store No.", store."No.");
        transactionStatus.SetRange(Status, transactionStatus.Status::Posted);
        if transactionStatus.FindLast() then
            statement."Trans. Starting Date" := transactionStatus.Date + 1
        else begin
            transaction.SetCurrentKey("Store No.", Date);
            transaction.SetRange("Store No.", store."No.");
            if transaction.FindFirst() then
                statement."Trans. Starting Date" := transaction.Date
            else
                exit(false);
        end;

        statement."Posting Date" := Today();

        exit(true);
    end;*/

    local procedure setDatesInStatement(var statement: Record "LSC Statement"; store: Record "LSC Store"): Boolean
    var
        transactionStatus: Record "LSC Transaction Status";
        transaction, transactionfD : Record "LSC Transaction Header";
        ParametrosFSN: Record "FSN Parameter";
        filter: Text;
    begin

        statement."Trans. Ending Date" := Today();
        transactionStatus.SetCurrentKey(Date);
        transactionStatus.SetRange("Store No.", store."No.");
        transactionStatus.SetRange(Status, transactionStatus.Status::Posted);
        if transactionStatus.FindLast() then
            statement."Trans. Starting Date" := transactionStatus.Date - 1
        else begin
            transaction.SetCurrentKey("Store No.", Date);
            transaction.SetRange("Store No.", store."No.");
            transaction.SetRange("Posted Statement No.", '');
            if transaction.FindFirst() then
                statement."Trans. Starting Date" := transaction.Date
            else
                exit(false);
        end;
        exit(true);
    end;

    procedure GlobalParametros(): Text
    var
        myInt: Integer;

    begin
        Parameter.Reset();
        Parameter.SetRange(Grupo, 'CONF');
        Parameter.SetRange(Codigo, 'STATEMENT');
        Parameter.SetRange(Activo, true);
        if Parameter.FindSet() then begin
            if Parameter.Descripcion <> '' then
                Sala := Parameter.Descripcion;
            if Parameter."Value Text 1" <> '' then
                FiltroFecha := CalcDate(Parameter."Value Text 1", Today);
            if Parameter.Port <> 0 then
                cantidad := Parameter.Port;
            if Parameter."Lookup ID 1" <> '' then
                if Evaluate(TimeLast, ConvertTo24HourFormat(Parameter."Lookup ID 1")) then;
            exit(Parameter.Valor);
        end else
            exit('');
    end;

    local procedure ConvertTo24HourFormat(TimeText: Text): Text
    var
        Hour, Minute, Second : Integer;
        PM: Boolean;
        Parts: List of [Text];
    begin
        // Ejemplo de entrada: "10:55:00 PM"
        Parts := TimeText.Split(' ');
        if Parts.Count = 2 then begin
            PM := (UpperCase(Parts.Get(2)) = 'PM');
            Parts := Parts.Get(1).Split(':');
            if Parts.Count = 3 then begin
                Evaluate(Hour, Parts.Get(1));
                Evaluate(Minute, Parts.Get(2));
                Evaluate(Second, Parts.Get(3));
                if PM and (Hour < 12) then
                    Hour := Hour + 12;
                if not PM and (Hour = 12) then
                    Hour := 0;
                exit(PadStr(Format(Hour), 2, '0') + ':' + PadStr(Format(Minute), 2, '0') + ':' + PadStr(Format(Second), 2, '0'));
            end;
        end;
        exit(TimeText); // Si no se puede convertir, regresa el texto original
    end;

    [EventSubscriber(ObjectType::Codeunit, CODEUNIT::"FSN Statement - Post", 'OnAfterCreateDocNo', '', false, false)]
    procedure OnAfterCreateDocNo(var DocNo: Code[50])
    var
        TransactionHeader: Record "LSC Transaction Header";
        StoreNo: Code[10];
        PosNo: Code[10];
        TransNo: Integer;
        ST: Codeunit "LSC Statement-Post";
        sff: Record "LSC Item Posting Buffer";
    begin
        ExplodeDocNo(DocNo, StoreNo, PosNo, TransNo);
        if not TransactionHeader.Get(StoreNo, PosNo, TransNo) then exit;
        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" <> '') then
            DocNo := TransactionHeader."Legal Serie" + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" <> '') and (TransactionHeader."Legal Serie" <> '') then
            DocNo := TransactionHeader."Legal Serie" + '-' + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" = '') then
            DocNo := TransactionHeader."Receipt No.";
    end;

    procedure ExplodeDocNo(DocNo: Code[20]; VAR StoreNo: Code[10]; VAR PosNo: Code[10]; VAR TransNo: Integer)
    var
        Position: Integer;
        cu: Codeunit "LSC Statement-Post";
        ta: Record "LSC Statement";
    begin
        StoreNo := '';
        PosNo := '';
        TransNo := 0;

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        StoreNo := CopyStr(DocNo, 1, Position - 1);
        DocNo := COPYSTR(DocNo, Position + 1);

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        PosNo := CopyStr(DocNo, 1, Position - 1);

        DocNo := COPYSTR(DocNo, Position + 1);

        if not EVALUATE(TransNo, DocNo) then TransNo := 0;
        exit;
    end;



    [EventSubscriber(ObjectType::Codeunit, CODEUNIT::"FSN Statement - Post", 'OnBeforeGenJnlPostLine', '', false, false)]
    procedure IDSOnBeforeGenJnlPostLine(var GenJournalLine: Record "Gen. Journal Line"; var Statement: Record "LSC Statement"; var TransactionHeader: Record "LSC Transaction Header")
    begin
        GenJournalLine."POS Store" := TransactionHeader."Store No.";
        GenJournalLine."POS Terminal" := TransactionHeader."POS Terminal No.";
        GenJournalLine."POS Transaction" := TransactionHeader."Transaction No.";
        GenJournalLine."Sub Type" := TransactionHeader."Sub Type";

        GenJournalLine."External Document No." := TransactionHeader."Store No." + '-' + TransactionHeader."POS Terminal No." + '-' + Format(TransactionHeader."Transaction No.");
        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" <> '') then
            GenJournalLine."Document No." := TransactionHeader."Legal Serie" + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" <> '') and (TransactionHeader."Legal Serie" <> '') then
            GenJournalLine."Document No." := TransactionHeader."Legal Serie" + '-' + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" = '') then
            GenJournalLine."Document No." := TransactionHeader."Receipt No.";
    end;


    [EventSubscriber(ObjectType::Table, Database::"Legal Ledger Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Legal_Ledger_Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "Legal Ledger Entry";
        RunTrigger: Boolean
    )
    var
        LegalLed: Record "Legal Ledger Entry";
    begin
        LegalLed.Reset();
        LegalLed.SetRange("No.", Rec."No.");
        if LegalLed.FindLast() then
            Rec."Line No." := LegalLed."Line No." + 100;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Trans. Sales Entry", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Trans. Sales Entry_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Trans. Sales Entry";
        var xRec: Record "LSC Trans. Sales Entry";
        RunTrigger: Boolean
    )
    begin
        if Rec.IsTemporary then
            exit;
        if Rec."Posting Exception Key" <> '' then
            Rec."Posting Exception Key" := '';

        if xRec."Posting Exception Key" <> '' then
            xRec."Posting Exception Key" := '';
    end;

    /////////////Recepcion compras
    [EventSubscriber(ObjectType::Table, Database::"Purch. Cr. Memo Line", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Purch. Cr. Memo Line_OnBeforeInsertEvent"
    (
    var Rec: Record "Purch. Cr. Memo Line";
    RunTrigger: Boolean
    )
    begin
        if (Rec.Type = Rec.Type::"G/L Account") then begin
            if Rec.Quantity = 0 then begin
                Rec.Quantity := 1;
                Rec."Amount Including VAT" := Rec."Direct Unit Cost";
                Rec.Amount := Rec."Direct Unit Cost";
                Rec."VAT Base Amount" := Rec."Direct Unit Cost";
                Rec."Unit Cost" := Rec."Direct Unit Cost";
                Rec."Line Amount" := Rec."Direct Unit Cost";
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeUpdatePurchLineBeforePost', '', true, true)]
    local procedure "Purch.-Post_OnBeforeUpdatePurchLineBeforePost"
    (
        var PurchaseLine: Record "Purchase Line";
        var PurchaseHeader: Record "Purchase Header";
        WhseShip: Boolean;
        WhseReceive: Boolean;
        RoundingLineInserted: Boolean;
        CommitIsSupressed: Boolean
    )
    begin
        if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Return Order" then begin
            if PurchaseLine.Type = PurchaseLine.Type::"G/L Account" then begin
                PurchaseLine.TestField("Return Qty. to Ship", PurchaseLine.Quantity);
                PurchaseLine.TestField("Qty. to Receive", 0);
                PurchaseLine.TestField("Qty. to Invoice", PurchaseLine.Quantity);
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnUpdatePurchLineBeforePostOnAfterCalcInitQtyToInvoiceNeeded', '', true, true)]
    local procedure "Purch.-Post_OnUpdatePurchLineBeforePostOnAfterCalcInitQtyToInvoiceNeeded"
    (
        var PurchHeader: Record "Purchase Header";
        var PurchLine: Record "Purchase Line";
        var InitQtyToInvoiceNeeded: Boolean
    )
    begin
        if PurchHeader."Document Type" = PurchHeader."Document Type"::"Return Order" then begin
            if PurchLine.Type = PurchLine.Type::"G/L Account" then begin
                InitQtyToInvoiceNeeded := false;
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemTrackingForShipmentOnBeforeReturnShipmentInvoiceErr', '', true, true)]
    local procedure "Purch.-Post_OnPostItemTrackingForShipmentOnBeforeReturnShipmentInvoiceErr"
    (
        PurchaseLine: Record "Purchase Line";
        var IsHandled: Boolean
    )
    var
        PurchHeader: Record "Purchase Header";
    begin
        if PurchHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            if PurchHeader."Document Type" = PurchHeader."Document Type"::"Return Order" then
                if PurchaseLine.Type = PurchaseLine.Type::"G/L Account" then begin
                    IsHandled := true;
                end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostItemTrackingCheckShipment', '', true, true)]
    local procedure "Purch.-Post_OnBeforePostItemTrackingCheckShipment"
    (
        PurchaseLine: Record "Purchase Line";
        RemQtyToBeInvoiced: Decimal;
        var IsHandled: Boolean
    )
    var
        PurchHeader: Record "Purchase Header";
    begin
        if PurchHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            if PurchHeader."Document Type" = PurchHeader."Document Type"::"Return Order" then
                if PurchaseLine.Type = PurchaseLine.Type::"G/L Account" then begin
                    IsHandled := true;
                end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Picking / Receiving lines_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Picking / Receiving lines";
        var xRec: Record "LSC Picking / Receiving lines";
        RunTrigger: Boolean
    )
    var
        PickingRecHeader: Record "LSC P/R Counting Header";
        RecervationEntry: Record "Reservation Entry";
        ReservEntry: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
    begin
        /* if PickingRecHeader.Get(Rec."Document No.") then
            IF PickingRecHeader.Receiving = PickingRecHeader.Receiving::"Purchase Order" then begin
                IF Rec."Lot No." <> '' THEN
                    CreateModifyReserVationEntry(Rec, PickingRecHeader);
            end; */

        if PickingRecHeader.Receiving = PickingRecHeader.Receiving::"Transfer In" then begin
            IF (Rec."Lot No." = '') or (Rec."Expiration Date" = 0D) THEN
                InsertLoteTransf(Rec, PickingRecHeader);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Picking / Receiving lines", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Picking / Receiving lines_OnBeforeInsertEvent"
(
    var Rec: Record "LSC Picking / Receiving lines";
    RunTrigger: Boolean
)
    var
        PickingRecHeader: Record "LSC P/R Counting Header";
        ReservEntry: Record "Reservation Entry";
    begin
        if PickingRecHeader.Get(Rec."Document No.") then begin
            /* IF PickingRecHeader.Receiving = PickingRecHeader.Receiving::"Purchase Order" then begin
                IF Rec."Lot No." <> '' THEN
                    CreateModifyReserVationEntry(Rec, PickingRecHeader);
            end; */

            if PickingRecHeader.Receiving = PickingRecHeader.Receiving::"Transfer In" then begin
                IF (Rec."Lot No." = '') or (Rec."Expiration Date" = 0D) THEN
                    InsertLoteTransf(Rec, PickingRecHeader);
            end;
        end;
    end;

    procedure InsertLoteTransf(var PickingL: Record "LSC Picking / Receiving lines"; PickingRecHeader: Record "LSC P/R Counting Header")
    var
        TransHeader: Record "Transfer header";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record "Item";
    begin
        if TransHeader.Get(PickingRecHeader."Reference No.") then
            if (Item.Get(PickingL."Item No.") and (Item."Item Tracking Code" <> '')) then begin
                ItemLedgerEntry.Reset();
                ItemLedgerEntry.SetRange("Item No.", PickingL."Item No.");
                ItemLedgerEntry.SetRange("Document No.", TransHeader."Last Shipment No.");
                if ItemLedgerEntry.FindFirst() then begin
                    if (PickingL."Lot No." = '') or (PickingL."Expiration Date" = 0D) then begin
                        PickingL."Lot No." := ItemLedgerEntry."Lot No.";
                        PickingL."Expiration Date" := ItemLedgerEntry."Expiration Date";
                    end;
                end;
            end;
    end;

    //Se valida desde la recepcion el numero de lote ingresado, si exite en reservacion
    procedure CreateModifyReserVationEntry(var PickRecLine: Record "LSC Picking / Receiving lines"; PickRecHeader: Record "LSC P/R Counting Header")
    var
        ReserVationEntry: Record "Reservation Entry";
    begin
        IF not VlidateexistsReservEntry(PickRecLine."Item No.", PickRecLine."Lot No.", PickRecHeader."Reference No.", ReserVationEntry) THEN BEGIN
            IF PickRecLine."Lot No." <> '' THEN
                CreateResEntry(PickRecLine, PickRecHeader);
        END else
            ModifyResEntry(PickRecLine, ReserVationEntry);
    end;

    //Se valida si existe el Numero de lote en Resercion
    procedure VlidateexistsReservEntry(Item: Code[20]; LotNo: Code[50]; OrderNo: Code[20]; var ReservationEntry: Record "Reservation Entry"): Boolean
    var
    begin
        ReservationEntry.Reset();
        ReservationEntry.SetRange(ReservationEntry."Item No.", Item);
        ReservationEntry.SetRange(ReservationEntry."Lot No.", LotNo);
        ReservationEntry.SetRange(ReservationEntry."Source ID", OrderNo);
        IF ReservationEntry.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    //Desde la recepcion se guarda informacion de producto con Numero de lote si no existe.
    procedure CreateResEntry(PickRecLine: Record "LSC Picking / Receiving lines"; PickingRecHeader: Record "LSC P/R Counting Header")
    var
        myInt: Integer;
        ReservEntry: Record "Reservation Entry";
        UOMMgt: Codeunit "Unit of Measure Management";
        PurchLine: Record "Purchase Line";
    begin
        ReservEntry."Entry No." := 0;
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Surplus;
        ReservEntry."Source Type" := 39;
        ReservEntry."Source Subtype" := ReservEntry."Source Subtype"::"1";
        ReservEntry."Item No." := PickRecLine."Item No.";
        ReservEntry."Lot No." := PickRecLine."Lot No.";
        ReservEntry."Expiration Date" := PickRecLine."Expiration Date";
        ReservEntry."New Expiration Date" := PickRecLine."Expiration Date";
        ReservEntry."Source ID" := PickingRecHeader."Reference No.";
        ReservEntry."Variant Code" := PickRecLine."Variant Code";
        ReservEntry."Location Code" := PickingRecHeader."Location Code";
        ReservEntry.Description := PickRecLine.Description;
        ReservEntry."Creation Date" := WorkDate;
        ReservEntry."Created By" := UserId;
        ReservEntry."Expected Receipt Date" := 0D;
        ReservEntry."Shipment Date" := 0D;
        ReservEntry.Positive := (PickRecLine.Quantity > 0);
        ReservEntry."Qty. per Unit of Measure" := PickRecLine."Qty. per Unit of Measure";
        ReservEntry."Quantity (Base)" := PickRecLine."Quantity (base)";
        if (ReservEntry."Quantity (Base)" <> 0) and ((ReservEntry.Quantity = 0)) then
            ReservEntry.Quantity := Round(PickRecLine."Quantity (Base)" / PickRecLine."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
        ReservEntry."Qty. to Handle (Base)" := ReservEntry."Quantity (Base)";
        ReservEntry."Qty. to Invoice (Base)" := ReservEntry."Quantity (Base)";
        PurchLine.Reset();
        PurchLine.SetRange(PurchLine."Document No.", PickingRecHeader."Reference No.");
        PurchLine.SetRange(PurchLine."No.", PickRecLine."Item No.");
        if PurchLine.FindFirst() then
            ReservEntry."Source Ref. No." := PurchLine."Line No."
        else
            ReservEntry."Source Ref. No." := PickRecLine."Line No.";
        ReservEntry."Item Tracking" := ReservEntry."Item Tracking"::"Lot No.";
        ReservEntry."Untracked Surplus" := ReservEntry."Untracked Surplus" and not ReservEntry.Positive;
        ReservEntry.Insert(true);
    end;

    //Si existe el lote en reservacion, solo se valida Cantidad base y fecha expiracion
    procedure ModifyResEntry(var PickRecLine: Record "LSC Picking / Receiving lines"; ReservEntry: Record "Reservation Entry")
    var
        myInt: Integer;
        ProcessModify: Boolean;
        UOMMgt: codeunit "Unit of Measure Management";
    begin
        if (ReservEntry."Quantity (Base)" <> PickRecLine."Quantity (Base)") or
            ((PickRecLine.Quantity = 0) or (ReservEntry."Qty. per Unit of Measure" <> PickRecLine."Qty. per Unit of Measure"))
        then begin
            ReservEntry.Quantity := Round(PickRecLine."Quantity (Base)" / PickRecLine."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision);
            ReservEntry."Quantity (Base)" := PickRecLine."Quantity (base)";
            ReservEntry."Qty. to Handle (Base)" := ReservEntry."Quantity (Base)";
            ReservEntry."Qty. to Invoice (Base)" := ReservEntry."Quantity (Base)";
            ProcessModify := true;
        end;

        if (PickRecLine."Expiration Date" <> 0D) then begin
            if ReservEntry."Expiration Date" <> PickRecLine."Expiration Date" then begin
                ReservEntry."Expiration Date" := PickRecLine."Expiration Date";
                ReservEntry."New Expiration Date" := PickRecLine."Expiration Date";
                ProcessModify := true;
            end;
        end else
            if (PickRecLine."Expiration Date" = 0D) and (ReservEntry."Expiration Date" <> 0D) then begin
                PickRecLine."Expiration Date" := ReservEntry."Expiration Date";
            end;

        if ProcessModify then
            ReservEntry.Modify(true);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Tracking Specification_OnBeforeInsertEvent"
    (
        var Rec: Record "Tracking Specification";
        RunTrigger: Boolean
    )
    var
        TransfHeader: Record "Transfer header";
    begin
        IF (Rec.IsTemporary) and not (TransfHeader.Get(Rec."Source ID")) THEN begin
            Rec."Qty. to Handle" := 0;
            Rec."Qty. to Invoice" := 0;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Reservation Entry_OnBeforeInsertEvent"
    (
        var Rec: Record "Reservation Entry";
        RunTrigger: Boolean
    )
    var
        TransfHeader: Record "Transfer header";
        TransLine: Record "Transfer Line";
    begin
        IF (TransfHeader.Get(Rec."Source ID")) THEN begin
            TransLine.Reset();
            TransLine.SetRange("Document No.", Rec."Source ID");
            TransLine.SetRange("Derived From Line No.", Rec."Source Prod. Order Line");
            transLine.SetRange("Transfer-from Code", 'OWN LOG.');
            IF TransLine.FindFirst() THEN BEGIN
                if Rec."Source Ref. No." <> TransLine."Line No." THEN
                    Rec."Source Ref. No." := TransLine."Line No.";
            END;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Engine Mgt.", 'OnInitRecordSetOnBeforeCheckItemTrackingExists', '', true, true)]
    local procedure "Reservation Engine Mgt._OnInitRecordSetOnBeforeCheckItemTrackingExists"
    (
        var CarriesItemTracking: Boolean;
        var TempSortRec1: Record "Reservation Entry";
        var IsHandled: Boolean
    )
    var
        Reset: Record "Reservation Entry";
    begin
        if TempSortRec1."Expiration Date" = 0D then begin
            Reset.Reset();
            Reset.SetRange(Reset."Item No.", TempSortRec1."Item No.");
            Reset.SetRange(Reset."Lot No.", TempSortRec1."Lot No.");
            Reset.SetRange("Location Code", TempSortRec1."Location Code");
            Reset.SetRange(Reset."Source ID", TempSortRec1."Source ID");
            Reset.SetRange(Reset."Source Ref. No.", TempSortRec1."Source Ref. No.");
            Reset.SetRange(Positive, true);
            Reset.SetFilter(Reset."Expiration Date", '<>%1', 0D);
            if Reset.FindFirst() then begin
                TempSortRec1."Expiration Date" := Reset."Expiration Date";
                TempSortRec1.Modify();
            end;
        end;
    end;
}