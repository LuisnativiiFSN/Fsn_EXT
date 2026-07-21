/// <summary>
/// Codeunit FSN Statement - Post (ID 50040).
/// </summary>
codeunit 50040 "FSN Statement - Post"
{
    Permissions = TableData "G/L Account" = r,
                  TableData Customer = r,
                  TableData "Gen. Journal Line" = rimd,
                  TableData "Item Journal Line" = rimd,
                  TableData "General Ledger Setup" = r,
                  TableData "Sales Shipment Header" = rm,
                  TableData "General Posting Setup" = r,
                  TableData "LSC Item Posting Buffer" = rimd,
                  TableData "LSC Posting Buffer" = rimd,
                  TableData "LSC Tender Type" = r,
                  TableData "LSC Store" = r,
                  TableData "LSC Transaction Header" = rm,
                  TableData "LSC Trans. Sales Entry" = rm,
                  TableData "LSC Trans. Payment Entry" = rm,
                  TableData "LSC Trans. Inc./Exp. Entry" = rm,
                  TableData "LSC Income/Expense Account" = r,
                  TableData "LSC Trans. Infocode Entry" = rm,
                  TableData "LSC Posted Statement" = rimd,
                  TableData "LSC Scheduler Setup" = r,
                  TableData "LSC Statement" = rm,
                  TableData "LSC Statement Line" = rm,
                  TableData "LSC Posted Statement Line" = rimd,
                  TableData "LSC Trans. Inventory Entry" = r,
                  TableData "LSC Tender TP Card No. Series" = r,
                  TableData "LSC Work Shift RBO" = rimd,
                  TableData "LSC Work Shift Entry" = rimd;
    TableNo = "LSC Statement";

    trigger OnRun()
    var
        ItemPostingBuffer_RV: Record "LSC Item Posting Buffer";
        ItemPostingBuffer_Temp: Record "LSC Item Posting Buffer";
        ReplenSetup: Record "LSC Replen. Setup";
        SafePost: Codeunit "LSC Safe Statement-Post";
        CommissionUtils: Codeunit "LSC Commission Utility";
        ReplenishmUpdLikeForLike: Codeunit "LSC Replen. Upd Like-for-Like";
        StatisticsUtils: Codeunit "LSC Statistics Utils";
        UpdateAnalysisView: Codeunit "Update Analysis View";
        DocumentNo: Code[20];
        CurrencyGainLoss: Decimal;
        ToBeRefunded: Decimal;
        BOMLineNo: Integer;
        i: Integer;
        Sign: Integer;
    begin
        LockTimeout(false);

        OnBeforeStatementPost(Rec);
        if not RunningFromBatchPosting then
            ClearAll;
        if not MealPlanningSetup.Get then
            Clear(MealPlanningSetup);

        ItemPostingBuffer[1].DeleteAll;
        ItemBuffer.DeleteAll;
        PostingBuffer[1].DeleteAll;
        BOMPostingBuffer[1].DeleteAll;
        BOMItemBuffer.DeleteAll;
        ItemAdjustPostBuffer[1].DeleteAll;
        TransPostingFunctions.InitFunction;
        Clear(RetailBOMJnlPostLine);
        Clear(ItemJnlPostLine);
        Clear(DiscLedgerMgt);
        if LocalizationExt.IsNALocalizationEnabled then begin
            TaxPostingBuffer.DeleteAll;
            tmpGenJnlLine.DeleteAll;
            TaxGenJnlPostingBuffer.DeleteAll;
            TransSalesTaxEntryTemp.DeleteAll;
        end;

        Statement := Rec;
        BackOfficeSetup.Get;
        BackOfficeSetup.TestField("Source Code");
        SchedulerSetup.Get;

        SalesReceivablesSetup.Get;
        Rec.TestField("Posting Date");
        Rec.TestField("Store No.");
        Store.Get(Rec."Store No.");
        Store.TestField("Store Gen. Bus. Post. Gr.");
        GenLedgerSetup.Get;
        CompletePost := true;
        if LocalizationExt.IsNALocalizationEnabled then
            UseSalesTax := BOUtils.UseSalesTax(Store."No.");

        if not RunningFromBatchPosting then
            "Cust/ItemChecks"(Statement, TRUE);
        if not PrePostingChecks(Statement, Store, RunningFromBatchPosting) then
            exit;

        if not Statement.Debugmode then
            Win.HideSubsequentDialogs(true);
        Win.Open(
          Text015 +
          Text016 +
          Text017 +
          Text018 +
          Text019 +
          Text020 +
          Text021 +
          Text022 +
          Text023 +
          Text024 +
          Text025 +
          Text026 +
          Text027 +
          Text028 +
          Text029 +
          ' #10################################ ');

        if not Statement.Debugmode then
            Win.Update(1, Rec."No.");
        Transaction.Reset;
        TransSalesEntry.Reset;
        TransPmtEntry.Reset;
        TransIncomeExpenseEntry.Reset;
        TransInfocodeEntry.Reset;
        TransInventoryEntry.Reset;

        if Rec."Posting No." = '' then begin
            Rec.TestField("Posting No. Series");
            if Rec."Posting No. Series" <> Rec."No. Series" then
                Rec."Posting No." := NoSeriesMgt.GetNextNo(Rec."Posting No. Series", Rec."Posting Date", true)
            else
                Rec."Posting No." := Rec."No.";
            Rec.Modify;
            Statement := Rec;
        end;

        OpenTablesBuffers();
        TransactionStatus.Reset;
        TransactionStatus.SetCurrentKey("Statement No.");
        TransactionStatus.SetRange("Statement No.", Rec."No.");

        if TransactionStatus.FindSet then
            repeat
                OnBeforeProcessTransactionStatus(TransactionStatus, Statement);
                if TransactionStatus.Status = TransactionStatus.Status::Posted then
                    Error(Text030, Rec.FieldCaption("No."), Rec."No.");
                Transaction.Get(TransactionStatus."Store No.", TransactionStatus."POS Terminal No.", TransactionStatus."Transaction No.");
                if Transaction."Transaction Type" = Transaction."Transaction Type"::Sales then
                    if not CheckTransSubTables(Transaction) then
                        Error(Text059, Rec.TableCaption, Rec."No.", TransSalesEntry.TableCaption, TransPmtEntry.TableCaption);
                if not Statement.Debugmode then
                    Win.Update(2, Transaction."Receipt No.");
                if Transaction."To Account" then begin
                    if not CustomerRec.Get(Transaction."Customer No.") then
                        Error(
                          Text031,
                          Transaction.FieldCaption("Customer No."), Transaction."Customer No.", CustomerRec.TableCaption);
                    TransSalesEntry.SetRange("Store No.", Transaction."Store No.");
                    TransSalesEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                    TransSalesEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                    if Transaction."Post as Shipment" then
                        MakeOrder(true)
                    else
                        if TransSalesEntry.FindSet then
                            repeat
                                DocumentNo := CreateDocNo(TransSalesEntry."Store No.",
                                  TransSalesEntry."POS Terminal No.",
                                  TransSalesEntry."Transaction No.");
                                PostItemSales(DocumentNo, true);
                            until TransSalesEntry.Next = 0;

                    TransIncomeExpenseEntry.SetRange("Store No.", Transaction."Store No.");
                    TransIncomeExpenseEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                    TransIncomeExpenseEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                    if TransIncomeExpenseEntry.FindSet then
                        repeat
                            DocumentNo := CreateDocNo(TransIncomeExpenseEntry."Store No.",
                              TransIncomeExpenseEntry."POS Terminal No.",
                              TransIncomeExpenseEntry."Transaction No.");
                            PostIncomeExpLine(DocumentNo);
                        until TransIncomeExpenseEntry.Next = 0;

                    if TransactionStatus."Customer Order ID" <> '' then
                        PostCOAmountToBeRefunded(DocumentNo);

                    DocumentNo := CreateDocNo(Transaction."Store No.",
                      Transaction."POS Terminal No.",
                      Transaction."Transaction No.");
                    PostToCustomer(DocumentNo);
                end else begin
                    TransSalesEntry.SetRange("Store No.", Transaction."Store No.");
                    TransSalesEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                    TransSalesEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                    if TransSalesEntry.FindSet then
                        repeat
                            PostItemSales(Rec."Posting No.", true);
                        until TransSalesEntry.Next = 0;

                    TransIncomeExpenseEntry.SetRange("Store No.", Transaction."Store No.");
                    TransIncomeExpenseEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                    TransIncomeExpenseEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                    if TransIncomeExpenseEntry.FindSet then
                        repeat
                            PostIncomeExpLine(Rec."Posting No.");
                        until TransIncomeExpenseEntry.Next = 0;

                    if TransactionStatus."Customer Order ID" <> '' then
                        PostCOAmountToBeRefunded(Rec."Posting No.");

                    if Transaction."Transaction Type" = Transaction."Transaction Type"::NegAdj then begin
                        TransInventoryEntry.SetRange("Store No.", Transaction."Store No.");
                        TransInventoryEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                        TransInventoryEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                        if TransInventoryEntry.FindSet then
                            repeat
                                PostNegAdjustment(Rec."Posting No.");
                            until TransInventoryEntry.Next = 0;
                    end;
                end;

                if glUndoItemPosting then
                    TransactionStatus.Status := TransactionStatus.Status::" "
                else
                    TransactionStatus.Status := TransactionStatus.Status::"Items Posted";

                if BackOfficeSetup."Autom. Statistics Update" and (not TransactionStatus."Included in Statistics") then
                    StatisticsUtils.UpdateTransactionStatistics(Transaction, TransactionStatus);
                OnAfterProcessTransactionStatus(TransactionStatus, Statement);
                TransStatusToBuffer(TransactionStatus);
            until TransactionStatus.Next = 0;

        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text033);

        StatementLine.Reset;
        StatementLine.SetRange("Statement No.", Rec."No.");
        StatementLine.SetFilter("Tender Type", '<>%1', '');
        if StatementLine.FindSet then
            repeat
                OnBeforeProcessStatementLine(StatementLine, Statement);
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(4, LineCounter);
                TenderType.Get(Store."No.", StatementLine."Tender Type");

                if StatementLine."Tender Type Card No." = '' then begin
                    if not (TenderType."Function" = TenderType."Function"::Customer) then begin
                        TenderType.TestField("Account No.");
                        TenderType.TestField("Difference G/L Acc.");
                    end;
                    AccType := TenderType."Account Type";
                    if AccType = AccType::"G/L Account" then
                        GLAccountNumber := TenderType."Account No."
                    else
                        BankAccNo := TenderType."Account No.";
                    DiffGLAccountNumber := TenderType."Difference G/L Acc.";

                    if TenderType."Foreign Currency" and (StatementLine."Currency Code" <> '') then
                        if TenderTypeCurrSetup.Get(Store."No.", StatementLine."Tender Type", StatementLine."Currency Code") then begin
                            if TenderTypeCurrSetup."Account No." <> '' then begin
                                AccType := TenderTypeCurrSetup."Account Type";
                                if AccType = AccType::"G/L Account" then
                                    GLAccountNumber := TenderTypeCurrSetup."Account No."
                                else
                                    BankAccNo := TenderTypeCurrSetup."Account No.";
                            end;
                            if TenderTypeCurrSetup."Difference G/L Acc." <> '' then
                                DiffGLAccountNumber := TenderTypeCurrSetup."Difference G/L Acc.";
                        end;

                end else begin
                    TenderTypeCardSetup.Get(
                      Store."No.", StatementLine."Tender Type", StatementLine."Tender Type Card No.");
                    if not (TenderType."Function" = TenderType."Function"::Customer) then begin
                        if (TenderTypeCardSetup."Account No." = '') or
                           (TenderTypeCardSetup."Difference G/L Acc." = '')
                        then begin
                            TenderType.TestField("Account No.");
                            TenderType.TestField("Difference G/L Acc.");
                            AccType := TenderType."Account Type";
                            if AccType = AccType::"G/L Account" then
                                GLAccountNumber := TenderType."Account No."
                            else
                                BankAccNo := TenderType."Account No.";
                            DiffGLAccountNumber := TenderType."Difference G/L Acc.";
                        end else begin
                            AccType := TenderTypeCardSetup."Account Type";
                            if AccType = AccType::"G/L Account" then
                                GLAccountNumber := TenderTypeCardSetup."Account No."
                            else
                                BankAccNo := TenderTypeCardSetup."Account No.";
                            DiffGLAccountNumber := TenderTypeCardSetup."Difference G/L Acc.";
                        end;
                    end;
                end;

                if not (TenderType."Function" = TenderType."Function"::Customer) then begin
                    CurrencyGainLoss := 0;
                    if AccType = AccType::"G/L Account" then begin
                        GLAccount.Get(GLAccountNumber);

                        Clear(GenJnlLine);
                        GenJnlLine.Init;
                        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                        GenJnlLine."Posting Date" := Rec."Posting Date";
                        GenJnlLine."Document Date" := Rec."Posting Date";
                        GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                        GenJnlLine."Document No." := Rec."Posting No.";
                        GenJnlLine."External Document No." := Rec."Posting No.";
                        GenJnlLine.Validate("Account No.", GLAccount."No.");
                        GenJnlLine.Description := StrSubstNo('%1 - %2', StatementLine."Tender Type Name", StatementLine.FieldCaption("Counted Amount"));
                        GenJnlLine."System-Created Entry" := true;
                        GenJnlLine.Amount := StatementLine."Counted Amount";
                        OnUpdateGnlSafeRefNo(GenJnlLine, SafeStatementLine);
                        if StatementLine."Currency Code" <> '' then begin
                            GenJnlLine.Validate("Currency Code", StatementLine."Currency Code");
                            CurrencyGainLoss := CurrencyGainLoss + GenJnlLine."Amount (LCY)" - StatementLine."Counted Amount in LCY";
                        end else
                            GenJnlLine.Validate("Currency Code", Store."Currency Code");
                        GenJnlLine."VAT Amount" := 0;
                        GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                        GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    end else begin
                        BankAcc.Get(BankAccNo);
                        Clear(GenJnlLine);
                        GenJnlLine.Init;
                        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"Bank Account";
                        GenJnlLine."Posting Date" := Rec."Posting Date";
                        GenJnlLine."Document Date" := Rec."Posting Date";
                        GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                        GenJnlLine."Document No." := Rec."Posting No.";
                        GenJnlLine."External Document No." := Rec."Posting No.";
                        GenJnlLine.Validate("Account No.", BankAcc."No.");
                        GenJnlLine.Description := StrSubstNo('%1 - %2', StatementLine."Tender Type Name", StatementLine.FieldCaption("Counted Amount"));
                        GenJnlLine."System-Created Entry" := true;
                        GenJnlLine.Amount := StatementLine."Counted Amount";
                        if StatementLine."Currency Code" <> '' then begin
                            GenJnlLine.Validate("Currency Code", StatementLine."Currency Code");
                            CurrencyGainLoss := CurrencyGainLoss + GenJnlLine."Amount (LCY)" - StatementLine."Counted Amount in LCY";
                        end else
                            GenJnlLine.Validate("Currency Code", Store."Currency Code");
                        GenJnlLine."VAT Amount" := 0;
                        GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                        GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    end;

                    OnBeforePostCustomerStatementLine(Statement, StatementLine, GenJnlLine, TotalSum);

                    if not Store."Paym. Compr. in Statem. Post." then begin
                        CreateGenJnlLineDim(
                          GenJnlLine,
                          DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                          DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                          Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                        if GenJnlLine."Amount (LCY)" <> 0 then begin
                            AddSourceCurrency(GenJnlLine);
                            OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                            GenJnlPostLine.RunWithCheck(GenJnlLine);
                        end;
                        TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                    end
                    else
                        UpdatePaymentBuffer(AccType, GenJnlLine."Account No.", StatementLine."Tender Type Name", GenJnlLine."Currency Code", GenJnlLine.Amount, StatementLine."Counted Amount in LCY");

                    if StatementLine."Difference in LCY" <> 0 then begin
                        GLAccount.Get(DiffGLAccountNumber);
                        Clear(GenJnlLine);
                        GenJnlLine.Init;
                        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                        GenJnlLine."Posting Date" := Rec."Posting Date";
                        GenJnlLine."Document Date" := Rec."Posting Date";
                        GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                        GenJnlLine."External Document No." := Rec."Posting No.";
                        GenJnlLine."Document No." := Rec."Posting No.";
                        GenJnlLine.Validate("Account No.", GLAccount."No.");
                        GenJnlLine.Description := Text034 + StatementLine."Tender Type";
                        GenJnlLine."System-Created Entry" := true;
                        GenJnlLine.Amount := -StatementLine."Difference Amount";
                        if StatementLine."Currency Code" <> '' then begin
                            GenJnlLine.Validate("Currency Code", StatementLine."Currency Code");
                            CurrencyGainLoss := CurrencyGainLoss + GenJnlLine."Amount (LCY)" + StatementLine."Difference in LCY";
                        end else
                            GenJnlLine.Validate("Currency Code", Store."Currency Code");
                        if not Store."Paym. Compr. in Statem. Post." then begin
                            GenJnlLine."Source Code" := BackOfficeSetup."Source Code";

                            CreateGenJnlLineDim(
                              GenJnlLine,
                              DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                              DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                              Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                            if GenJnlLine."Amount (LCY)" <> 0 then begin
                                AddSourceCurrency(GenJnlLine);
                                OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                                GenJnlPostLine.RunWithCheck(GenJnlLine);
                            end;
                            TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                        end
                        else
                            UpdatePaymentBuffer(0, GenJnlLine."Account No.", GenJnlLine.Description, GenJnlLine."Currency Code", GenJnlLine.Amount, -StatementLine."Difference in LCY");
                    end;
                    if not Store."Paym. Compr. in Statem. Post." then
                        if CurrencyGainLoss <> 0 then begin
                            Currency.Get(StatementLine."Currency Code");
                            if CurrencyGainLoss > 0 then
                                GLAccount.Get(Currency."Realized Gains Acc.")
                            else
                                GLAccount.Get(Currency."Realized Losses Acc.");
                            Clear(GenJnlLine);
                            GenJnlLine.Init;
                            GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                            GenJnlLine."Posting Date" := Rec."Posting Date";
                            GenJnlLine."Document Date" := Rec."Posting Date";
                            GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                            GenJnlLine."External Document No." := Rec."Posting No.";
                            GenJnlLine."Document No." := Rec."Posting No.";
                            GenJnlLine.Validate("Account No.", GLAccount."No.");
                            GenJnlLine.Description := StrSubstNo(Text054, StatementLine."Tender Type", StatementLine."Currency Code");
                            GenJnlLine."System-Created Entry" := true;
                            GenJnlLine.Validate(Amount, -CurrencyGainLoss);

                            GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                            CreateGenJnlLineDim(
                              GenJnlLine,
                              DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                              DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                              Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                            if GenJnlLine."Amount (LCY)" <> 0 then begin
                                AddSourceCurrency(GenJnlLine);
                                OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                                GenJnlPostLine.RunWithCheck(GenJnlLine);
                            end;
                            TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                        end;
                end;
                OnAfterProcessTransactionStatus(TransactionStatus, Statement);
            until StatementLine.Next = 0;

        if Store."Paym. Compr. in Statem. Post." then
            PostPaymentBuffer;

        LineCounter := 0;
        SafeStatementLine.Reset;
        SafeStatementLine.SetRange("Statement No.", Rec."No.");
        SafeStatementLine.SetFilter("Tender Type", '<>%1', '');
        if SafeStatementLine.FindFirst then
            repeat
                OnBeforeProcessSafeStatementLine(SafeStatementLine, Statement);
                Sign := 1;
                LineCounter := LineCounter + 1;
                TenderType.Get(Store."No.", SafeStatementLine."Tender Type");
                TenderType.TestField("Account No.");
                TenderType.TestField("Difference G/L Acc.");

                AccType := TenderType."Account Type";
                if AccType = AccType::"G/L Account" then
                    GLAccountNumber := TenderType."Account No."
                else
                    BankAccNo := TenderType."Account No.";
                DiffGLAccountNumber := TenderType."Difference G/L Acc.";
                if TenderType."Foreign Currency" and (SafeStatementLine."Currency Code" <> '') then
                    if TenderTypeCurrSetup.Get(Store."No.", SafeStatementLine."Tender Type", SafeStatementLine."Currency Code") then begin
                        if TenderTypeCurrSetup."Account No." <> '' then begin
                            AccType := TenderTypeCurrSetup."Account Type";
                            if AccType = AccType::"G/L Account" then
                                GLAccountNumber := TenderTypeCurrSetup."Account No."
                            else
                                BankAccNo := TenderTypeCurrSetup."Account No.";
                        end;
                        if TenderTypeCurrSetup."Difference G/L Acc." <> '' then
                            DiffGLAccountNumber := TenderTypeCurrSetup."Difference G/L Acc.";
                    end;

                if AccType = AccType::"G/L Account" then begin
                    GLAccount.Get(GLAccountNumber);
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", GLAccount."No.");
                    GenJnlLine.Description := SafeStatementLine.Description;
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine.Amount;
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."VAT Amount" := 0;
                    GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');

                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                end
                else begin
                    BankAcc.Get(BankAccNo);
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"Bank Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine."External Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", BankAcc."No.");
                    GenJnlLine.Description := SafeStatementLine.Description;
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine.Amount;
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."VAT Amount" := 0;
                    GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";

                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                end;

                Sign := -1;

                if SafeStatementLine."Difference in LCY" <> 0 then begin
                    GLAccount.Get(DiffGLAccountNumber);
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."External Document No." := Rec."Posting No.";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", GLAccount."No.");
                    GenJnlLine.Description := Text034 + SafeStatementLine."Tender Type";
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine."Difference Amount";
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                    TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                end;

                Sign := -1;

                Clear(GLAccountNumber);
                Clear(BankAccNo);

                if SafeStatementLine."Bal. Account Type" = SafeStatementLine."Bal. Account Type"::"G/L Account" then
                    GLAccountNumber := SafeStatementLine."Bal. Account No."
                else
                    if SafeStatementLine."Bal. Account Type" = SafeStatementLine."Bal. Account Type"::"Bank Account" then
                        BankAccNo := SafeStatementLine."Bal. Account No.";

                if GLAccountNumber <> '' then begin
                    GLAccount.Get(GLAccountNumber);
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", GLAccount."No.");
                    GenJnlLine.Description := SafeStatementLine.Description;
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine.Amount;
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."VAT Amount" := 0;
                    GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');

                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                end
                else begin
                    BankAcc.Get(BankAccNo);
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"Bank Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine."External Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", BankAcc."No.");
                    GenJnlLine.Description := SafeStatementLine.Description;
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine.Amount;
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."VAT Amount" := 0;
                    GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";

                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                end;

                Sign := 1;

                if SafeStatementLine."Difference in LCY" <> 0 then begin
                    GLAccount.Get(TenderType."Bank Diff. G/L Acc.");
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                    GenJnlLine."Posting Date" := Rec."Posting Date";
                    GenJnlLine."Document Date" := Rec."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."External Document No." := Rec."Posting No.";
                    GenJnlLine."Document No." := Rec."Posting No.";
                    GenJnlLine.Validate("Account No.", GLAccount."No.");
                    GenJnlLine.Description := Text034 + SafeStatementLine."Tender Type";
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := Sign * SafeStatementLine."Difference Amount";
                    if SafeStatementLine."Currency Code" <> '' then
                        GenJnlLine.Validate("Currency Code", SafeStatementLine."Currency Code")
                    else
                        GenJnlLine.Validate("Currency Code", Store."Currency Code");
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                    TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                end;
                OnAfterProcessSafeStatementLine(SafeStatementLine, Statement);
            until SafeStatementLine.Next = 0;

        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text035);
        PostingBuffer[1].Reset;

        if PostingBuffer[1].FindSet then
            repeat
                OnBeforeProcessGLPostingBuffer(PostingBuffer[1], Statement, TempDimBufPost);
                LineCounter := LineCounter + 1;
                if PostingBuffer[1]."G/L Account" = '' then
                    Error(
                      Text036,
                      PostingBuffer[1].Type,
                      PostingBuffer[1]."Gen. Business Posting Group",
                      PostingBuffer[1]."Gen. Product Posting Group",
                      PostingBuffer[1].Amount,
                      PostingBuffer[1]."InfoCode Discount Amount",
                      PostingBuffer[1]."Cust. Discount Amount");
                GLAccount.Get(PostingBuffer[1]."G/L Account");
                if not Statement.Debugmode then
                    Win.Update(5, LineCounter);
                Clear(GenJnlLine);
                GenJnlLine.Init;
                GenJnlLine."Posting Date" := Rec."Posting Date";
                GenJnlLine."Document Date" := Rec."Posting Date";
                GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                GenJnlLine."Document No." := PostingBuffer[1]."Document No.";
                GenJnlLine."External Document No." := Statement."Posting No.";
                GenJnlLine.Validate("Account No.", PostingBuffer[1]."G/L Account");
                GenJnlLine.Description := GLAccount.Name;
                GenJnlLine."Gen. Bus. Posting Group" := PostingBuffer[1]."Gen. Business Posting Group";
                GenJnlLine."Gen. Prod. Posting Group" := PostingBuffer[1]."Gen. Product Posting Group";
                GenJnlLine."VAT Bus. Posting Group" := PostingBuffer[1]."VAT Business Posting Group";
                GenJnlLine."VAT Prod. Posting Group" := PostingBuffer[1]."VAT Product Posting Group";
                GenJnlLine.Validate("VAT Bus. Posting Group");
                GenJnlLine."System-Created Entry" := true;
                if GLAccount."Gen. Posting Type" = GLAccount."Gen. Posting Type"::Purchase then
                    GenJnlLine."Gen. Posting Type" := GenJnlLine."Gen. Posting Type"::Purchase
                else
                    GenJnlLine."Gen. Posting Type" := GenJnlLine."Gen. Posting Type"::Sale;
                GenJnlLine.Validate("Currency Code", PostingBuffer[1]."Currency Code");
                CurrencyFactor := GenJnlLine."Currency Factor";
                GenJnlLine.Amount := PostingBuffer[1].Amount;
                GenJnlLine."VAT Amount" := PostingBuffer[1]."VAT Amount";
                GenJnlLine."VAT Base Amount" := PostingBuffer[1]."VAT Base Amount";
                if GenJnlLine."Currency Code" <> '' then begin
                    Currency.Get(GenJnlLine."Currency Code");
                    GenJnlLine.Amount := Round(GenJnlLine.Amount, Currency."Amount Rounding Precision");
                    GenJnlLine."VAT Amount" := Round(GenJnlLine."VAT Amount", Currency."Amount Rounding Precision");
                    GenJnlLine."VAT Base Amount" := Round(GenJnlLine."VAT Base Amount", Currency."Amount Rounding Precision");
                    GenJnlLine."Amount (LCY)" :=
                      Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                        Rec."Posting Date", GenJnlLine."Currency Code", PostingBuffer[1].Amount, CurrencyFactor));
                    GenJnlLine."VAT Amount (LCY)" :=
                      Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                        Rec."Posting Date", GenJnlLine."Currency Code", PostingBuffer[1]."VAT Amount", CurrencyFactor));
                    GenJnlLine."VAT Base Amount (LCY)" :=
                      Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                        Rec."Posting Date", GenJnlLine."Currency Code", PostingBuffer[1]."VAT Base Amount", CurrencyFactor));
                end else begin
                    GenJnlLine.Amount := Round(GenJnlLine.Amount, GenLedgerSetup."Amount Rounding Precision");
                    GenJnlLine."VAT Amount" := Round(GenJnlLine."VAT Amount", GenLedgerSetup."Amount Rounding Precision");
                    GenJnlLine."VAT Base Amount" := Round(GenJnlLine."VAT Base Amount", GenLedgerSetup."Amount Rounding Precision");
                end;
                if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
                    GenJnlLine."Tax Area Code" := PostingBuffer[1]."Tax Area Code";
                    GenJnlLine."Tax Liable" := PostingBuffer[1]."Tax Liable";
                    GenJnlLine."Tax Group Code" := PostingBuffer[1]."Tax Group Code";
                    GenJnlLine."Use Tax" := PostingBuffer[1]."Use Tax";
                    GenJnlLine."VAT Calculation Type" := PostingBuffer[1]."VAT Calculation Type";
                end;
                GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                GenJnlLine."Shortcut Dimension 1 Code" := PostingBuffer[1]."Department Code";
                GenJnlLine."Shortcut Dimension 2 Code" := PostingBuffer[1]."Project Code";
                GenJnlLine."Source Code" := BackOfficeSetup."Source Code";

                if PostingBuffer[1]."Customer No." <> '' then begin
                    CustomerRec.Get(PostingBuffer[1]."Customer No.");
                    GenJnlLine."Sell-to/Buy-from No." := PostingBuffer[1]."Customer No.";
                    GenJnlLine."Bill-to/Pay-to No." := PostingBuffer[1]."Customer No.";
                    GenJnlLine."Country/Region Code" := CustomerRec."Country/Region Code";
                    GenJnlLine."VAT Registration No." := CustomerRec."VAT Registration No.";
                    GenJnlLine."Source Type" := GenJnlLine."Source Type"::Customer;
                    GenJnlLine."Source No." := PostingBuffer[1]."Customer No.";
                end;

                if PostingBuffer[1].isDiscount then begin
                    GenJnlLine."Gen. Posting Type" := 0;
                    GenJnlLine."EU 3-Party Trade" := false;
                    if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then
                        GenJnlLine."VAT Calculation Type" := GenJnlLine."VAT Calculation Type"::"Sales Tax"
                    else
                        GenJnlLine."VAT Calculation Type" := GenJnlLine."VAT Calculation Type"::"Normal VAT";
                    GenJnlLine."Bill-to/Pay-to No." := '';
                end;

                TempDimBufNew.DeleteAll;
                TempDimSetEntry.DeleteAll;
                if GetDimensions(PostingBuffer[1]."Entry No.", TempDimBufNew) then begin
                    if TempDimBufNew.FindSet then
                        repeat
                            DimVal.Get(TempDimBufNew."Dimension Code", TempDimBufNew."Dimension Value Code");
                            TempDimSetEntry."Dimension Code" := TempDimBufNew."Dimension Code";
                            TempDimSetEntry."Dimension Value Code" := TempDimBufNew."Dimension Value Code";
                            TempDimSetEntry."Dimension Value ID" := DimVal."Dimension Value ID";
                            TempDimSetEntry.Insert;
                        until TempDimBufNew.Next = 0;
                    GenJnlLine."Dimension Set ID" := DimMgt.GetDimensionSetID(TempDimSetEntry);
                end;

                OnBeforeProcessPostingBuffer(GenJnlLine, PostingBuffer[1], Statement);

                GenJnlPostLine.RunWithCheck(GenJnlLine);
                TotalSum := TotalSum + GenJnlLine."Amount (LCY)" + GenJnlLine."VAT Amount (LCY)";
                OnAfterProcessPostingBuffer(PostingBuffer[1], Statement);
            until PostingBuffer[1].Next = 0;

        PostingBuffer[1].DeleteAll;

        if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then
            PostTax('T' + DelChr(Format(TransSalesEntry."Transaction No."), '=', ',.'));

        if not Statement.Debugmode then
            Win.Update(10, Text037);

        OnBeforeCalculateRoundingDifference(Statement, GenJnlLine, TotalSum);

        if TotalSum <> 0 then begin
            Store.TestField("Rounding Account");
            if Store."Max. Round. in Stmt." <> 0 then
                if Store."Max. Round. in Stmt." < Abs(TotalSum) then
                    Error(
                      Text038,
                      TotalSum, Store.FieldCaption("Max. Round. in Stmt."),
                      Store."Max. Round. in Stmt.", Store.TableCaption, Store."No.");
            GLAccount.Get(Store."Rounding Account");
            Clear(GenJnlLine);
            GenJnlLine.Init;
            GenJnlLine."Posting Date" := Rec."Posting Date";
            GenJnlLine."Document Date" := Rec."Posting Date";
            GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
            GenJnlLine."Document No." := Rec."Posting No.";
            GenJnlLine."External Document No." := Statement."Posting No.";
            GenJnlLine.Validate("Account No.", GLAccount."No.");
            GenJnlLine.Description := GLAccount.Name;
            if GenJnlLine."VAT %" <> 0 then begin
                GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                GenJnlLine."VAT Amount" := -TotalSum * (1 - (1 / (1 + (GenJnlLine."VAT %" / 100))));
                GenJnlLine.Amount := -TotalSum - GenJnlLine."VAT Amount";
                GenJnlLine."VAT Base Amount" := GenJnlLine.Amount;
                GenJnlLine.Amount := Round(GenJnlLine.Amount, GenLedgerSetup."Amount Rounding Precision");
                GenJnlLine."VAT Amount" := Round(GenJnlLine."VAT Amount", GenLedgerSetup."Amount Rounding Precision");
                GenJnlLine."VAT Base Amount" := Round(GenJnlLine."VAT Base Amount", GenLedgerSetup."Amount Rounding Precision");
            end else
                GenJnlLine.Validate(Amount, -TotalSum);
            GenJnlLine."System-Created Entry" := true;
            GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
            CreateGenJnlLineDim(
              GenJnlLine,
              DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
              DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
              Database::"LSC Store", Store."No.", 0, '', 0, '', '');
            AddSourceCurrency(GenJnlLine);
            OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
            GenJnlPostLine.RunWithCheck(GenJnlLine);
        end;

        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text050);
        if BOMItemBuffer.FindSet then begin
            BOMItemBuffer2.DeleteAll;
            repeat
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(6, LineCounter);
                BOMCalcStdCost(BOMItemBuffer."Item No.", BOMItemBuffer.Date);
            until BOMItemBuffer.Next = 0;
        end;
        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text051);
        BOMLineNo := 0;
        if BOMPostingBuffer[1].FindSet then
            repeat
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(6, LineCounter);
                PostBOM;
                Clear(GenJnlPostLine);
            until BOMPostingBuffer[1].Next = 0;
        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text060);
        ItemAdjustPostBuffer[1].Reset;
        if ItemAdjustPostBuffer[1].FindSet then
            repeat
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(6, LineCounter);
                PostItemAdjustment;
            until ItemAdjustPostBuffer[1].Next = 0;
        TransPostingFunctions.InsertInvAdjustEntry(ItemAdjustPostBuffer[1]);
        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text039);
        ItemPostingBuffer[1].Reset;
        ItemPostingBuffer[1].SetRange(Type, ItemPostingBuffer[1].Type::Sales);
        if ItemPostingBuffer[1].FindSet then
            repeat
                OnBeforeProcessItemPostingBuffer(ItemPostingBuffer[1], Statement);
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(6, LineCounter);
                if (ItemPostingBuffer[1]."Serial No." <> '') or (ItemPostingBuffer[1]."Lot No." <> '') then begin
                    CompressItemPostingBuffer;
                    if OkToPostDirect(ItemPostingBuffer[1]) then
                        PostItem
                    else
                        if FindReversePosting(ItemPostingBuffer[1], ItemPostingBuffer_RV) then begin
                            ItemPostingBuffer_Temp := ItemPostingBuffer[1];
                            ItemPostingBuffer[1] := ItemPostingBuffer_RV;
                            PostItem;
                            ItemPostingBuffer[1] := ItemPostingBuffer_Temp;
                            PostItem;
                        end else
                            PostItem;
                    ItemPostingBuffer[1].Delete;
                end else
                    PostItem;
                OnAfterProcessItemPostingBuffer(ItemPostingBuffer[1], Statement);
            until ItemPostingBuffer[1].Next = 0;

        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text046);
        ItemPostingBuffer[1].Reset;
        ItemPostingBuffer[1].SetRange(Type, ItemPostingBuffer[1].Type::NegAdjust);
        if ItemPostingBuffer[1].FindSet then
            repeat
                OnBeforeProcessItemPostingBuffer(ItemPostingBuffer[1], Statement);
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(6, LineCounter);
                if ItemPostingBuffer[1].Quantity <> 0 then begin
                    Item.Get(ItemPostingBuffer[1]."Item No.");
                    TransPostingFunctions.SetItemBlockReserve(Item."No.");
                    Clear(ItemJnlLine);
                    ItemJnlLine.Init;
                    ItemJnlLine."Item No." := ItemPostingBuffer[1]."Item No.";
                    ItemJnlLine."Variant Code" := ItemPostingBuffer[1]."Source No.";
                    ItemJnlLine."Posting Date" := ItemPostingBuffer[1].Date;
                    ItemJnlLine."Document Date" := Rec."Posting Date";
                    ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::"Negative Adjmt.");
                    ItemJnlLine."Document No." := ItemPostingBuffer[1]."Document No.";
                    ItemJnlLine.Description := Item.Description;
                    ItemJnlLine."Location Code" := ItemPostingBuffer[1]."Location Code";
                    ItemJnlLine."Inventory Posting Group" := Item."Inventory Posting Group";
                    ItemJnlLine."Source Posting Group" := '';
                    if Item."Base Unit of Measure" <> '' then begin
                        ItemJnlLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
                        ItemJnlLine.Validate(Quantity, ItemPostingBuffer[1].Quantity);
                    end else begin
                        ItemJnlLine."Unit of Measure Code" := '';
                        ItemJnlLine."Qty. per Unit of Measure" := 1;
                        ItemJnlLine.Validate("Quantity (Base)", ItemPostingBuffer[1].Quantity);
                    end;
                    ItemJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    ItemJnlLine."Gen. Bus. Posting Group" := ItemPostingBuffer[1]."Gen. Bus. Posting Group";
                    ItemJnlLine."Gen. Prod. Posting Group" := ItemPostingBuffer[1]."Gen. Prod. Posting Group";
                    ItemJnlLine."LSC Offer No." := ItemPostingBuffer[1]."Offer No.";
                    ItemJnlLine."LSC Promotion No." := ItemPostingBuffer[1]."Promotion No.";

                    ItemJnlLine."Expiration Date" := ItemPostingBuffer[1]."Expiration Date";
                    if (ItemPostingBuffer[1]."Serial No." <> '') or (ItemPostingBuffer[1]."Lot No." <> '') then
                        TransPostingFunctions.AddSerialNoAndLotNoTracking(ItemJnlLine, ItemPostingBuffer[1]."Serial No.", ItemPostingBuffer[1]."Lot No.", ItemPostingBuffer[1]."Expiration Date");

                    i := 1;
                    Clear(TableID);
                    Clear(No);
                    TableID[i] := Database::Item;
                    No[i] := ItemJnlLine."Item No.";
                    i += 1;
                    TableID[i] := Database::"LSC Store";
                    No[i] := Store."No.";
                    CreateItemJnlLineDim(ItemJnlLine, TableID, No, '');
                    OnBeforeItemJnlLinePostLine(ItemJnlLine, Statement, ItemPostingBuffer[1]);
                    ItemJnlPostLine.RunWithCheck(ItemJnlLine);
                    OnAfterItemJnlLinePostLine(ItemJnlLine, Statement);
                    TransPostingFunctions.ResetItemBlockReserve;
                end;
                OnAfterProcessItemPostingBuffer(ItemPostingBuffer[1], Statement);
            until ItemPostingBuffer[1].Next = 0;

        ItemPostingBuffer[1].SetRange(Type);
        ItemPostingBuffer[1].DeleteAll;

        if not Statement.Debugmode then
            Win.Update(10, Text040);

        TransSalesEntry.Reset;
        TransPmtEntry.Reset;
        TransIncomeExpenseEntry.Reset;
        TransInventoryEntry.Reset;
        LineCounter := 0;
        LineCounter2 := 0;
        LineCounter3 := 0;

        GetTransStatusBuffer(TransactionStatusTmp);
        if TransactionStatusTmp.FindSet then
            repeat
                OnBeforeEndProcessTransactionStatus(TransactionStatusTmp, Statement);
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(7, LineCounter);
                TransactionStatusTmp.Status := TransactionStatus.Status::Posted;
                TransactionStatusTmp."Posted Statement No." := Rec."Posting No.";
                OnBeforeEndProcessTransactionStatus(TransactionStatusTmp, Statement);
                TransStatusToBuffer(TransactionStatusTmp);
            until TransactionStatusTmp.Next = 0;

        if Rec."Closing Method" = Rec."Closing Method"::Shift then begin
            WorkShift.Get(Rec."Store No.", Rec."Shift Date", Rec."Shift No.");
            WorkShift.Status := WorkShift.Status::Posted;
            WorkShift.Modify;
            WorkShiftEntry.SetRange("Store No.", WorkShift."Store No.");
            WorkShiftEntry.SetRange("Shift Date", WorkShift."Shift Date");
            WorkShiftEntry.SetRange("Shift No.", WorkShift."Shift No.");
            if WorkShiftEntry.FindSet then
                repeat
                    WorkShiftEntry.Status := WorkShiftEntry.Status::Posted;
                    WorkShiftEntry."Closing Date" := Today;
                    WorkShiftEntry."Closing Time" := Time;
                    WorkShiftEntry.Modify;
                until WorkShiftEntry.Next = 0;
        end;

        Rec."Posted Date" := Today;
        Rec."Posted Time" := Time;
        Rec.Modify;

        SafePost.PostStatement(Rec);

        PostedStatement.Init;
        PostedStatement.TransferFields(Rec);
        PostedStatement."No." := Rec."Posting No.";
        PostedStatement."No. Series" := Rec."Posting No. Series";
        PostedStatement."Pre-Assigned No. Series" := Rec."No. Series";
        PostedStatement."Pre-Assigned No." := Rec."No.";

        Rec.CalcFields(
          "Items/Barc. Not on File", "Trans. on Wrong Shift", "Sales Amount",
          "VAT Amount", "Total Discount", "Line Discount", Income, Expenses, "Discount Total Amount",
          "No. of Blocked Items", "No. of Blocked Cust.", "Trans. w/ Sale/Pmt. Diff.");
        PostedStatement."Items/Barc. Not on File" := Rec."Items/Barc. Not on File";
        PostedStatement."Trans. on Wrong Shift" := Rec."Trans. on Wrong Shift";
        PostedStatement."Sales Amount" := Rec."Sales Amount";
        PostedStatement."VAT Amount" := Rec."VAT Amount";
        PostedStatement."Total Discount" := Rec."Total Discount";
        PostedStatement."Line Discount" := Rec."Line Discount";
        PostedStatement."Discount Total Amount" := Rec."Discount Total Amount";
        PostedStatement.Income := Rec.Income;
        PostedStatement.Expenses := Rec.Expenses;
        PostedStatement."No. of Blocked Items" := Rec."No. of Blocked Items";
        PostedStatement."No. of Blocked Cust." := Rec."No. of Blocked Cust.";
        PostedStatement."Trans. w/ Sale/Pmt. Diff." := Rec."Trans. w/ Sale/Pmt. Diff.";

        PostedStatement.Insert(true);

        StatementLine.SetRange("Statement No.", Statement."No.");
        if StatementLine.FindSet then
            repeat
                PostedStatementLine.Init;
                PostedStatementLine.TransferFields(StatementLine);
                PostedStatementLine."Statement No." := Rec."Posting No.";
                OnBeforeInsertPostedStatementLine(StatementLine, PostedStatementLine);
                PostedStatementLine.Insert(true);
            until StatementLine.Next = 0;
        Clear(StatementLine);
        StatementLine.SetRange("Statement No.", Statement."No.");
        StatementLine.DeleteAll;

        SafeStatementLine.SetRange("Statement No.", Statement."No.");
        if SafeStatementLine.FindSet then
            repeat
                PostedSafeStatementLine.Init;
                PostedSafeStatementLine.TransferFields(SafeStatementLine);
                PostedSafeStatementLine."Statement No." := Rec."Posting No.";
                PostedSafeStatementLine.Insert(true);
            until SafeStatementLine.Next = 0;
        Clear(SafeStatementLine);
        SafeStatementLine.SetRange("Statement No.", Statement."No.");
        SafeStatementLine.DeleteAll;

        CashDeclaration.SetRange("Statement No.", Rec."No.");
        if CashDeclaration.FindSet then
            repeat
                PostedCashDeclaration.Init;
                PostedCashDeclaration.TransferFields(CashDeclaration);
                PostedCashDeclaration."Statement No." := Rec."Posting No.";
                PostedCashDeclaration.Insert;
            until CashDeclaration.Next = 0;
        CashDeclaration.DeleteAll;

        FlushTablesBuffers;

        if not Statement.Debugmode then
            Win.Close;

        OnBeforeDeleteStatement(Rec);

        Clear(Statement);
        Statement := Rec;
        Statement.Delete;
        TransPostingFunctions.CloseFunction;

        UpdateAnalysisView.UpdateAll(0, true);

        if SchedulerSetup."Statment Post Repl. Job" <> '' then begin
            SchedulerJob.Get(SchedulerSetup."Statment Post Repl. Job");
            SchedulerJob.SetLogEntryNo(0);
            SchedulerJob.SetLocationCode('');
            SchedulerUtil.RunScheduleJob(SchedulerJob, true);
            SchedulerJob.Modify;
        end;

        BOUtils.ReplicateUsingRegEntry;

        OnAfterStatementPostBeforeCommit(Rec);

        if (BOUtils.IsReplenishmentPermitted) and
          (ReplenSetup.Get) then begin
            Commit;
            ReplenishmUpdLikeForLike.UpdateLikeForLikeFromStmt(PostedStatement."No.");
        end;

        if BackOfficeSetup."Commission Active" and BackOfficeSetup."Calculate in Statem.Posting" then begin
            CommissionUtils.SetRunFromPosting(true);
            CommissionUtils.StatementPosting(PostedStatement."No.");
        end;

        if ShowReturnOrderMsg then
            if FirstReturnOrderNo = LastReturnOrderNo then
                Message(Text055, FirstReturnOrderNo)
            else
                Message(Text056, FirstReturnOrderNo, LastReturnOrderNo);

        OnAfterStatementPost(Rec);
    end;

    var
        Store: Record "LSC Store";
        BackOfficeSetup: Record "LSC Retail Setup";
        SchedulerSetup: Record "LSC Scheduler Setup";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        Statement: Record "LSC Statement";
        StatementLine: Record "LSC Statement Line";
        PostedStatement: Record "LSC Posted Statement";
        PostedStatementLine: Record "LSC Posted Statement Line";
        Transaction: Record "LSC Transaction Header";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        TransPmtEntry: Record "LSC Trans. Payment Entry";
        TransIncomeExpenseEntry: Record "LSC Trans. Inc./Exp. Entry";
        TransInfocodeEntry: Record "LSC Trans. Infocode Entry";
        TenderType: Record "LSC Tender Type";
        TenderTypeCardSetup: Record "LSC Tender Type Card Setup";
        CustomerRec: Record Customer;
        GenJnlLine: Record "Gen. Journal Line";
        ItemJnlLine: Record "Item Journal Line";
        Item: Record Item;
        IncomeExpenseAcc: Record "LSC Income/Expense Account";
        GenPostingSetup: Record "General Posting Setup";
        PostingBuffer: array[2] of Record "LSC Posting Buffer" temporary;
        PaymPostingBuffer: Record "LSC Posting Buffer" temporary;
        ItemPostingBuffer: array[2] of Record "LSC Item Posting Buffer" temporary;
        ItemBuffer: Record "LSC Item Posting Buffer" temporary;
        GLAccount: Record "G/L Account";
        GLAccount2: Record "G/L Account";
        BankAcc: Record "Bank Account";
        WorkShift: Record "LSC Work Shift RBO";
        WorkShiftEntry: Record "LSC Work Shift Entry";
        VATPostingSetup: Record "VAT Posting Setup";
        OldCustLedgEntry: Record "Cust. Ledger Entry";
        CurrencyExchRate: Record "Currency Exchange Rate";
        Currency: Record Currency;
        GenLedgerSetup: Record "General Ledger Setup";
        TempDimBufNew: Record "Dimension Buffer" temporary;
        TempDimBufPost: Record "Dimension Buffer" temporary;
        TempDimSetEntry: Record "Dimension Set Entry" temporary;
        DimVal: Record "Dimension Value";
        CashDeclaration: Record "LSC Cash Declaration";
        PostedCashDeclaration: Record "LSC Posted Cash Declaration";
        BOMPostingBuffer: array[2] of Record "LSC BOM Posting Buffer" temporary;
        RetailBOMJnlLine: Record "LSC Retail BOM Journal Line";
        TransInventoryEntry: Record "LSC Trans. Inventory Entry";
        TmpInteger: Record "Integer" temporary;
        SchedulerJob: Record "LSC Scheduler Job Header";
        TransactionStatus: Record "LSC Transaction Status";
        TransactionStatusTmp: Record "LSC Transaction Status" temporary;
        TransSalesEntryStatus: Record "LSC Trans. Sales Entry Status";
        SalesTypes: Record "LSC Sales Type";
        SafeStatementLine: Record "LSC Safe Statement Line";
        PostedSafeStatementLine: Record "LSC Posted Safe Statement Line";
        MealPlanningSetup: Record "LSC Meal Planning Setup";
        BOMItemBuffer: Record "LSC BOM Posting Buffer" temporary;
        BOMItemBuffer2: Record "LSC BOM Posting Buffer" temporary;
        TenderTypeCurrSetup: Record "LSC Tender Type Currency Setup";
        TaxPostingBuffer: Record "LSC Posting Buffer" temporary;
        TaxGenJnlPostingBuffer: Record "LSC Posting Buffer" temporary;
        TransSalesTaxEntryTemp: Record "LSC Trans. SalesTax Entry" temporary;
        tmpGenJnlLine: Record "Gen. Journal Line" temporary;
        SourceCodeSetup: Record "Source Code Setup";
        SourceCode: Record "Source Code";
        ItemAdjustPostBuffer: array[2] of Record "LSC Item Posting Buffer" temporary;
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        DimManagement: Codeunit DimensionManagement;
        DimMgt: Codeunit DimensionManagement;
        RetailBOMJnlPostLine: Codeunit "LSC Retail BOM Jnl.-Post Line";
        SchedulerUtil: Codeunit "LSC Scheduler Util";
        DiscLedgerMgt: Codeunit "LSC Discount Ledger Mgt.";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        PostingExceptionUtility: Codeunit "LSC Posting Exception Utility";
        TransPostingFunctions: Codeunit "LSC Trans. Posting Functions";
        RetailItemJnlExt: Codeunit "LSC Retail Item Jnl. Ext.";
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";
        BufferUtility: Codeunit "LSC Buffer Utility";
        BOUtils: Codeunit "LSC BO Utils";
        Win: Dialog;
        Txt: Text[250];
        GLAccountNumber: Code[20];
        BankAccNo: Code[20];
        DiffGLAccountNumber: Code[20];
        GLSetupShortcutDimCode: array[8] of Code[20];
        No: array[10] of Code[20];
        FirstReturnOrderNo: Code[20];
        LastReturnOrderNo: Code[20];
        DocType: Enum "Gen. Journal Document Type";
        TotalSum: Decimal;
        TotDiff: Decimal;
        TotCounted: Decimal;
        CurrencyFactor: Decimal;
        AmountToPost: Decimal;
        LineCounter: Integer;
        LineCounter2: Integer;
        LineCounter3: Integer;
        TableID: array[10] of Integer;
        BufferLineNo: Integer;
        CountedAmtChecked: Boolean;
        AccType: Option "G/L Account","Bank Account";
        HasGotGLSetup: Boolean;
        CompletePost: Boolean;
        UseSalesTax: Boolean;
        ShowReturnOrderMsg: Boolean;
        RunningFromBatchPosting: Boolean;
        glUndoItemPosting: Boolean;
        LastPostingGrId: code[10];
        GenBusPostingGrId: Dictionary of [Code[20], Code[10]];
        GenProductPostingGrId: Dictionary of [Code[20], Code[10]];
        VATBusPostingGrId: Dictionary of [Code[20], Code[10]];
        VATProductPostingGrid: Dictionary of [Code[20], Code[10]];
        Text046: Label 'Posting Negative Adjustment';
        Text047: Label 'Item Posting can''t be undone';
        Text050: Label 'Updating BOM Cost';
        Text051: Label 'Posting BOM To Stock';
        Text052: Label 'Posting cannot be completed successfully. %1 %2  belongs to the %3 that requires creating service items. Check if the %4 field contains a whole number.';
        Text053: Label 'Tender Type specifically used for deposits is missing for Store %1';
        Text054: Label 'Tender Type %1, currency %2 gains/losses';
        Text055: Label 'Return Order %1 has been created. It needs to be received.';
        Text056: Label 'Return Orders %1 to %2 have been created. They need to be received.';
        Text057: Label 'The %1 sales entries were sucessfully posted';
        Text059: Label 'Unable to post %1 %2.\Some %3 and/or %4 are missing.  Run the "Check Transactions" function for detailed information';
        Text060: Label 'Posting Inv. Adjust.';
        ExplanationMsg: Label 'Item %1 with Serial No. %2 was sold and returned on two different transactions, see receipts %3 and %4. The transactions must be selected on the same statement or their statements must be posted in a chronological order.';
        Text10000: Label 'Posting Tax To G/L ';
        Text000: Label '%1 and %2 are more than 30 days apart.\';
        Text001: Label 'Do you still want to continue posting?';
        Text002: Label 'Posting was cancelled.';
        Text006: Label 'There are %1 blocked %2 records in the %3 %4 records. \\';
        Text007: Label 'Do you want to temporarily unblock the %2 records until posting is completed?';
        Text008: Label 'There are %1 %2 records with difference between sales and payment amount greater than %3 - %4. \\';
        Text009: Label 'Counted Amount is missing from at least one statement line. \';
        Text010: Label 'You cannot post because the difference in the lines is %1.\';
        Text011: Label 'It exceeds %2, the %3 for the %4.';
        Text012: Label 'The difference in the lines is %1. \\';
        Text013: Label 'Do you want to continue the posting?';
        Text014: Label 'No Statement Lines found.';
        Text015: Label '   Posting Statement #1##################\\\';
        Text016: Label ' Buffering Dimensions....\';
        Text017: Label '    Transactions          #11################# \';
        Text018: Label '    Sales Entries         #12################# \\\';
        Text019: Label ' Transactions....\';
        Text020: Label '    Receipt No.           #2################## \';
        Text021: Label '    Line                  #3##################\\\';
        Text022: Label ' Posting......\';
        Text023: Label '    Statement Line        #4################## \';
        Text024: Label '    Posting Sales To G/L  #5################## \';
        Text025: Label '    Updating stock        #6################## \\\';
        Text026: Label ' Marking Transactions\';
        Text027: Label '    Headers               #7################## \';
        Text028: Label '    Sales Lines           #8################## \';
        Text029: Label '    Payment Lines         #9################## \\\';
        Text030: Label '%1 %2 is already Posted.';
        Text031: Label '%1 %2 does not exist in %3.';
        Text033: Label 'Posting statement lines';
        Text034: Label 'Statement difference ';
        Text035: Label 'Posting Sales To G/L ';
        Text036: Label 'Type %1 \ PostGr %2 PostGr2 %3 \ Amount %4 \ L Disc %5 \ Inv disc %6';
        Text037: Label 'Posting Rounding Difference';
        Text038: Label 'Rounding Amount %1 is higher than %2 - %3 in %4 %5.';
        Text039: Label 'Posting Sales To Stock';
        Text040: Label 'Marking Headers as posted';
        Text041: Label 'The %1 %2 was successfully posted.';
        Text042: Label 'Slip ';
        Text043: Label 'Payment ';
        Text044: Label 'The Statement was calculated before all POS Terminals were closed.';
        PostingNotReadyQst: Label 'Not all POS/Cashiers are ready for posting. Do you want to exclude the relevant Transactions from the Statement?';
        PostingReadyMsg: Label 'Incomplete Transactions have been excluded from this Statement, please calculate them in a new Statement. This Statement is now ready for posting.';
        StatementNotReadyMsg: Label 'This Statement is not ready to be posted due to missing End of Day Declaration.';

    [Scope('OnPrem')]
    procedure PostItemSales(DocNumber: Code[20]; PostGLEntries: Boolean)
    var
        Staff: Record "LSC Staff";
        SalesType2: Record "LSC Sales Type";
        PostingException: Record "LSC Posting Exception";
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        LocCode: Code[10];
        SalesTypeCode: Code[20];
        VATFactor: Decimal;
        CustDiscountAmount: Decimal;
        CustDiscountVATAmount: Decimal;
        POSInvDiscAmount: Decimal;
        POSInvDiscVATAmount: Decimal;
        InfoCodeDiscountAmount: Decimal;
        InfoCodeDiscVATAmount: Decimal;
        POSLineDiscAmount: Decimal;
        POSLineDiscVATAmount: Decimal;
        PeriodicDiscAmount: Decimal;
        PeriodicDiscVATAmount: Decimal;
        CouponDiscAmount: Decimal;
        CouponDiscVATAmount: Decimal;
        POSLineDiscOfferAmount: Decimal;
        POSLineDiscOfferVATAmount: Decimal;
        POSTotalDiscOfferAmount: Decimal;
        POSTotalDiscOfferVATAmount: Decimal;
        POSTenderDiscOfferAmount: Decimal;
        POSTenderDiscOfferVATAmount: Decimal;
        TmpDiscAmt: Decimal;
        EntryNo: Integer;
        Len: Integer;
        OfferType: Option Promotion,Deal,Multibuy,"Mix&Match","Disc. Offer","Total Discount","Tender Type","Item Point","Line Discount",Customer,Infocode,"Member Point",Coupon,Total,Line;
        IsHandled: Boolean;
        GenBusPostingGroup: Code[20];
        GenProdPostingGroup: Code[20];
        VATBusPostingGroup: Code[20];
        VATProdPostingGroup: Code[20];
    begin
        OnBeforePostItemSalesExit(TransSalesEntry, Transaction, Statement, IsHandled);
        if IsHandled then
            exit;

        OnBeforePostItemSales(TransSalesEntry, Transaction, Statement);

        Item.Get(TransSalesEntry."Item No.");

        GenBusPostingGroup := TransSalesEntry."Gen. Bus. Posting Group";
        if GenBusPostingGroup = '' then
            if Transaction."To Account" then
                GenBusPostingGroup := CustomerRec."Gen. Bus. Posting Group"
            else
                GenBusPostingGroup := Store."Store Gen. Bus. Post. Gr.";

        GenProdPostingGroup := TransSalesEntry."Gen. Prod. Posting Group";
        if GenProdPostingGroup = '' then
            GenProdPostingGroup := Item."Gen. Prod. Posting Group";

        GenPostingSetup.get(GenBusPostingGroup, GenProdPostingGroup);

        VATBusPostingGroup := TransSalesEntry."VAT Bus. Posting Group";
        if VATBusPostingGroup = '' then
            VATBusPostingGroup := Transaction."VAT Bus.Posting Group";
        VATProdPostingGroup := TransSalesEntry."VAT Prod. Posting Group";
        if VATProdPostingGroup = '' then
            VATProdPostingGroup := Item."VAT Prod. Posting Group";
        VATPostingSetup.get(VATBusPostingGroup, VATProdPostingGroup);

        OnAfterGetVATPostingSetup(VATPostingSetup, Transaction, TransSalesEntry, GenPostingSetup);

        VATFactor := (1 + (VATPostingSetup."VAT %" / 100));
        if VATPostingSetup."VAT Calculation Type" <> VATPostingSetup."VAT Calculation Type"::"Normal VAT" then
            VATFactor := 1;

        Clear(TableID);
        Clear(No);

        TableID[1] := Database::Item;
        No[1] := Item."No.";
        TableID[2] := Database::"LSC Store";
        No[2] := Store."No.";
        TableID[3] := Database::"G/L Account";

        if Transaction."Sale Is Return Sale" then
            No[3] := GenPostingSetup."Sales Credit Memo Account"
        else
            No[3] := GenPostingSetup."Sales Account";

        Len := 3;
        if Transaction."Customer No." <> '' then begin
            TableID[4] := Database::Customer;
            No[4] := Transaction."Customer No.";
            Len := 4;
        end;

        SalesTypeCode := Transaction."Sales Type";
        if TransSalesEntry."Sales Type" <> '' then
            SalesTypeCode := TransSalesEntry."Sales Type";

        if SalesTypeCode <> '' then begin
            Len := Len + 1;
            TableID[Len] := Database::"LSC Sales Type";
            No[Len] := SalesTypeCode;
        end;

        GetDefaultDim(
            TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
            GlobalDimension2Code, Len);

        EntryNo := FindDimensions(TempDimBufNew);
        if EntryNo = 0 then
            EntryNo := InsertDimensions(TempDimBufNew);

        if PostGLEntries then begin
            Clear(PostingBuffer[1]);
            PostingBuffer[1].Type := PostingBuffer[1].Type::Item;
            GenPostingSetup.TestField("Sales Account");
            if Transaction."To Account" then
                PostingBuffer[1]."Customer No." := CustomerRec."No.";
            PostingBuffer[1]."Entry No." := EntryNo;

            if Transaction."Sale Is Return Sale" then begin
                GenPostingSetup.TestField("Sales Credit Memo Account");
                PostingBuffer[1]."G/L Account" := GenPostingSetup."Sales Credit Memo Account";
            end
            else
                PostingBuffer[1]."G/L Account" := GenPostingSetup."Sales Account";

            PostingBuffer[1]."Gen. Business Posting Group" := GenPostingSetup."Gen. Bus. Posting Group";
            PostingBuffer[1]."Gen. Product Posting Group" := GenPostingSetup."Gen. Prod. Posting Group";
            PostingBuffer[1]."VAT Business Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
            PostingBuffer[1]."VAT Product Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
            AssignPostingGrIds(PostingBuffer[1]);
            if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then
                PostingBuffer[1]."VAT Calculation Type" := TransSalesEntry."VAT Calculation Type"::"Sales Tax"
            else
                PostingBuffer[1]."VAT Calculation Type" := PostingBuffer[1]."VAT Calculation Type"::"Normal VAT";
            PostingBuffer[1]."Department Code" := GlobalDimension1Code;
            PostingBuffer[1]."Project Code" := GlobalDimension2Code;
            PostingBuffer[1]."Currency Code" := Transaction."Trans. Currency";
            PostingBuffer[1]."Document No." := DocNumber;
            PostingBuffer[1].Amount := TransSalesEntry."Net Amount";
            PostingBuffer[1]."VAT Base Amount" := TransSalesEntry."Net Amount";
            if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
                PostingBuffer[1]."VAT Amount" := TransSalesEntry."VAT Amount" +
                                                 TransSalesEntry."Sales Tax Rounding";
                if TransSalesEntry."VAT Calculation Type" = TransSalesEntry."VAT Calculation Type"::"Sales Tax" then begin
                    PostingBuffer[1]."Tax Area Code" := Transaction."Tax Area Code";
                    PostingBuffer[1]."Tax Group Code" := TransSalesEntry."Tax Group Code";
                    PostingBuffer[1]."Tax Liable" := Transaction."Tax Liable";
                    PostingBuffer[1]."Tax Exemption No." := Transaction."Tax Exemption No.";
                    PostingBuffer[1]."Use Tax" := false;
                    PostingBuffer[1].Quantity := TransSalesEntry.Quantity;
                end;
            end else
                PostingBuffer[1]."VAT Amount" := TransSalesEntry."VAT Amount";

            Clear(CustDiscountAmount);
            Clear(POSInvDiscAmount);
            Clear(InfoCodeDiscountAmount);
            Clear(POSLineDiscAmount);
            Clear(PeriodicDiscAmount);
            Clear(CouponDiscAmount);
            Clear(POSLineDiscOfferAmount);
            Clear(POSTotalDiscOfferAmount);
            Clear(POSTenderDiscOfferAmount);
            Clear(CustDiscountVATAmount);
            Clear(POSInvDiscVATAmount);
            Clear(InfoCodeDiscVATAmount);
            Clear(POSLineDiscVATAmount);
            Clear(PeriodicDiscVATAmount);
            Clear(CouponDiscVATAmount);
            Clear(POSLineDiscOfferVATAmount);
            Clear(POSTotalDiscOfferVATAmount);
            Clear(POSTenderDiscOfferVATAmount);

            if BackOfficeSetup."Post Cust. Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::Customer);
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Cust. Disc. Account");
                    CustDiscountAmount := Round(TmpDiscAmt / VATFactor);
                    CustDiscountVATAmount := Round(TmpDiscAmt - CustDiscountAmount);
                end;
            end;

            if BackOfficeSetup."Post Total Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::Total);
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Inv. Disc. Account");
                    POSInvDiscAmount := Round(TransSalesEntry."Total Discount" / VATFactor);
                    POSInvDiscVATAmount := Round(TransSalesEntry."Total Discount" - POSInvDiscAmount);
                end;
            end;

            if BackOfficeSetup."Post Infocode Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::Infocode);
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS InfoCode Disc. Account");
                    InfoCodeDiscountAmount := Round(TmpDiscAmt / VATFactor);
                    InfoCodeDiscVATAmount := Round(TmpDiscAmt - InfoCodeDiscountAmount);
                end;
            end;

            if BackOfficeSetup."Post Line Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::Line);
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Line Disc. Account");
                    POSLineDiscAmount := Round(TmpDiscAmt / VATFactor);
                    POSLineDiscVATAmount := Round(TmpDiscAmt - POSLineDiscAmount);
                end;
            end;

            if BackOfficeSetup."Post Periodic Disc." then begin
                TmpDiscAmt :=
                  GetTransLineDiscAmount(TransSalesEntry, OfferType::Multibuy) +
                  GetTransLineDiscAmount(TransSalesEntry, OfferType::"Mix&Match") +
                  GetTransLineDiscAmount(TransSalesEntry, OfferType::"Item Point") +
                  GetTransLineDiscAmount(TransSalesEntry, OfferType::"Disc. Offer");
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Periodic Disc. Account");
                    PeriodicDiscAmount := Round(TmpDiscAmt / VATFactor);
                    PeriodicDiscVATAmount := Round(TmpDiscAmt - PeriodicDiscAmount);
                end;
            end;

            if BackOfficeSetup."Post Coupon Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::Coupon);
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Coup. Disc. Account");
                    CouponDiscAmount := Round(TmpDiscAmt / VATFactor);
                    CouponDiscVATAmount := Round(TmpDiscAmt - CouponDiscAmount);
                end;
            end;

            if BackOfficeSetup."Post Line Disc. Offer" then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::"Line Discount");
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Line. Disc. Offer Acc.");
                    POSLineDiscOfferAmount := Round(TmpDiscAmt / VATFactor);
                    POSLineDiscOfferVATAmount := Round(TmpDiscAmt - POSLineDiscOfferAmount);
                end;
            end;

            if BackOfficeSetup."Post Total Disc. Offer" then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::"Total Discount");
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Total Disc. Offer Acc.");
                    POSTotalDiscOfferAmount := Round(TmpDiscAmt / VATFactor);
                    POSTotalDiscOfferVATAmount := Round(TmpDiscAmt - POSTotalDiscOfferAmount);
                end;
            end;

            if BackOfficeSetup."Post Tender Type Disc." then begin
                TmpDiscAmt := GetTransLineDiscAmount(TransSalesEntry, OfferType::"Tender Type");
                if TmpDiscAmt <> 0 then begin
                    GenPostingSetup.TestField("LSC POS Tender Type Disc. Acc.");
                    POSTenderDiscOfferAmount := Round(TmpDiscAmt / VATFactor);
                    POSTenderDiscOfferVATAmount := Round(TmpDiscAmt - POSTenderDiscOfferAmount);
                end;
            end;

            PostingBuffer[1].Amount :=
              PostingBuffer[1].Amount - CustDiscountAmount - POSInvDiscAmount
              - InfoCodeDiscountAmount - POSLineDiscAmount
              - PeriodicDiscAmount - CouponDiscAmount
              - POSLineDiscOfferAmount - POSTotalDiscOfferAmount - POSTenderDiscOfferAmount;

            if not UseSalesTax and not LocalizationExt.IsNALocalizationEnabled then begin
                PostingBuffer[1]."VAT Base Amount" := PostingBuffer[1].Amount;
                PostingBuffer[1]."VAT Amount" :=
                  PostingBuffer[1]."VAT Amount" - CustDiscountVATAmount - POSInvDiscVATAmount
                   - InfoCodeDiscVATAmount - POSLineDiscVATAmount
                   - PeriodicDiscVATAmount - CouponDiscVATAmount
                   - POSLineDiscOfferVATAmount - POSTotalDiscOfferVATAmount - POSTenderDiscOfferVATAmount;
            end;
            OnBeforeUpdPostingBufferInPostItemSales(PostingBuffer[1], TransSalesEntry);
            UpdPostingBuffer;

            if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
                if CustDiscountAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Cust. Disc. Account", CustDiscountAmount);

                if POSInvDiscAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Inv. Disc. Account", POSInvDiscAmount);

                if InfoCodeDiscountAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS InfoCode Disc. Account", InfoCodeDiscountAmount);

                if POSLineDiscAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Line Disc. Account", POSLineDiscAmount);

                if PeriodicDiscAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Periodic Disc. Account", PeriodicDiscAmount);

                if CouponDiscAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Coup. Disc. Account", CouponDiscAmount);

                if POSLineDiscOfferAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Line. Disc. Offer Acc.", POSLineDiscOfferAmount);

                if POSTotalDiscOfferAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Total Disc. Offer Acc.", POSTotalDiscOfferAmount);

                if POSTenderDiscOfferAmount <> 0 then
                    PostDiscountBufferingTax(Len, GenPostingSetup."LSC POS Tender Type Disc. Acc.", POSTenderDiscOfferAmount);
            end else begin
                if CustDiscountAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Cust. Disc. Account", CustDiscountAmount, CustDiscountVATAmount, SalesTypeCode);

                if POSInvDiscAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Inv. Disc. Account", POSInvDiscAmount, POSInvDiscVATAmount, SalesTypeCode);

                if InfoCodeDiscountAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS InfoCode Disc. Account", InfoCodeDiscountAmount, InfoCodeDiscVATAmount, SalesTypeCode);

                if POSLineDiscAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Line Disc. Account", POSLineDiscAmount, POSLineDiscVATAmount, SalesTypeCode);

                if PeriodicDiscAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Periodic Disc. Account", PeriodicDiscAmount, PeriodicDiscVATAmount, SalesTypeCode);

                if CouponDiscAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Coup. Disc. Account", CouponDiscAmount, CouponDiscVATAmount, SalesTypeCode);

                if POSLineDiscOfferAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Line. Disc. Offer Acc.", POSLineDiscOfferAmount, POSLineDiscOfferVATAmount, SalesTypeCode);

                if POSTotalDiscOfferAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Total Disc. Offer Acc.", POSTotalDiscOfferAmount, POSTotalDiscOfferVATAmount, SalesTypeCode);

                if POSTenderDiscOfferAmount <> 0 then
                    PostDiscountBuffering(Len, GenPostingSetup."LSC POS Tender Type Disc. Acc.", POSTenderDiscOfferAmount, POSTenderDiscOfferVATAmount, SalesTypeCode);
            end;
        end;

        TransSalesEntryStatus.Get(TransSalesEntry."Store No.", TransSalesEntry."POS Terminal No.", TransSalesEntry."Transaction No.", TransSalesEntry."Line No.");

        if (TransSalesEntryStatus.Status <> TransSalesEntryStatus.Status::"Items Posted") or
           ((TransSalesEntryStatus.Status = TransSalesEntryStatus.Status::"Items Posted") and (glUndoItemPosting))
        then begin
            if (TransSalesEntryStatus.Status <> TransSalesEntryStatus.Status::"Items Posted") and (Item."Service Item Group" <> '') then
                CreateServItemOnTransSalesEnt(Transaction, TransSalesEntry, Statement."No.");

            Clear(ItemPostingBuffer[1]);
            ItemPostingBuffer[1].Type := ItemPostingBuffer[1].Type::Sales;

            ItemPostingBuffer[1]."Serial No." := TransSalesEntry."Serial No.";
            ItemPostingBuffer[1]."Lot No." := TransSalesEntry."Lot No.";
            ItemPostingBuffer[1]."Expiration Date" := TransSalesEntry."Expiration Date";
            ItemPostingBuffer[1]."Item No." := TransSalesEntry."Item No.";

            if TransSalesEntry."Gen. Bus. Posting Group" <> '' then
                ItemPostingBuffer[1]."Gen. Bus. Posting Group" := TransSalesEntry."Gen. Bus. Posting Group"
            else
                ItemPostingBuffer[1]."Gen. Bus. Posting Group" := Store."Store Gen. Bus. Post. Gr.";
            if TransSalesEntry."Gen. Prod. Posting Group" <> '' then
                ItemPostingBuffer[1]."Gen. Prod. Posting Group" := TransSalesEntry."Gen. Prod. Posting Group"
            else
                ItemPostingBuffer[1]."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";

            LocCode := Store."Location Code";
            if SalesTypeCode <> '' then
                if SalesType2.Get(SalesTypeCode) then
                    if SalesType2."Location Code" <> '' then
                        LocCode := SalesType2."Location Code";
            ItemPostingBuffer[1]."Location Code" := LocCode;
            ItemPostingBuffer[1]."Department Code" := Store."Global Dimension 1 Code";
            ItemPostingBuffer[1]."Document No." := DocNumber;
            if glUndoItemPosting then
                ItemPostingBuffer[1].Quantity := TransSalesEntry.Quantity
            else
                ItemPostingBuffer[1].Quantity := -TransSalesEntry.Quantity;
            ItemPostingBuffer[1]."Neg. Qty" := ItemPostingBuffer[1].Quantity <= 0;
            ItemPostingBuffer[1].Amount := -TransSalesEntry."Net Amount";
            ItemPostingBuffer[1]."Cost Amount" := -TransSalesEntry."Cost Amount";
            ItemPostingBuffer[1]."Offer No." := TransSalesEntry."Periodic Disc. Group";

            ItemPostingBuffer[1]."Promotion No." := TransSalesEntry."Promotion No.";
            ItemPostingBuffer[1]."Sales Type" := SalesTypeCode;
            ItemPostingBuffer[1]."Inv. Discount Amount" := Round(TransSalesEntry."Discount Amount" / VATFactor);

            CreateDiscBuffer(TransSalesEntry, VATFactor);

            if glUndoItemPosting then begin
                ItemPostingBuffer[1].Amount := -ItemPostingBuffer[1].Amount;
                ItemPostingBuffer[1]."Cost Amount" := -ItemPostingBuffer[1]."Cost Amount";
                ItemPostingBuffer[1]."Inv. Discount Amount" := -ItemPostingBuffer[1]."Inv. Discount Amount";
                ItemPostingBuffer[1]."Line Discount Amount" := -ItemPostingBuffer[1]."Line Discount Amount";
                DiscLedgerMgt.RevertSignCurrDiscBuffer;
            end;
            if TransSalesEntry."Variant Code" <> '' then
                ItemPostingBuffer[1]."Source No." := TransSalesEntry."Variant Code";
            if Transaction."To Account" then
                ItemPostingBuffer[1]."Customer No." := CustomerRec."No.";

            if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
                ItemPostingBuffer[1].Date := TransSalesEntry.Date
            else
                ItemPostingBuffer[1].Date := Statement."Posting Date";

            if Transaction."Trans. Currency" <> '' then begin
                CurrencyFactor := CurrencyExchRate.ExchangeRate(ItemPostingBuffer[1].Date, Transaction."Trans. Currency");

                ItemPostingBuffer[1].Amount :=
                  Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                    ItemPostingBuffer[1].Date, Transaction."Trans. Currency", ItemPostingBuffer[1].Amount, CurrencyFactor));
                ItemPostingBuffer[1]."Cost Amount" :=
                  Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                    ItemPostingBuffer[1].Date, Transaction."Trans. Currency", ItemPostingBuffer[1]."Cost Amount", CurrencyFactor));
                ItemPostingBuffer[1]."Inv. Discount Amount" :=
                  Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                    ItemPostingBuffer[1].Date, Transaction."Trans. Currency", ItemPostingBuffer[1]."Inv. Discount Amount", CurrencyFactor));
                ItemPostingBuffer[1]."Line Discount Amount" :=
                  Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                    ItemPostingBuffer[1].Date, Transaction."Trans. Currency", ItemPostingBuffer[1]."Line Discount Amount", CurrencyFactor));
                DiscLedgerMgt.ExchFCYToLCYCurrDiscBuffer(ItemPostingBuffer[1].Date, Transaction."Trans. Currency", CurrencyFactor);
            end;

            if (TransSalesEntry."Sales Staff" <> '') and Staff.Get(TransSalesEntry."Sales Staff") and (Staff."Sales Person" <> '') then
                ItemPostingBuffer[1]."Salesperson Code" := Staff."Sales Person";

            Clear(PostingException);
            if TransSalesEntry."Posting Exception Key" <> '' then
                PostingExceptionUtility.FindItremPostExSetupByKey(TransSalesEntry."Posting Exception Key", PostingException);

            Item.CalcFields("Assembly BOM");
            if (Item."Assembly BOM") or
               ((Item."LSC Fuel Item") and (TransSalesEntry."Variant Code" <> ''))
            then begin
                if (Item."LSC Upd Cost and Weight w/Post") or (Item."LSC Fuel Item") then begin
                    if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
                        BOMItemBuffer.Date := TransSalesEntry.Date
                    else
                        BOMItemBuffer.Date := Statement."Posting Date";
                    if not BOMItemBuffer.Get('', '', TransSalesEntry."Item No.", '', BOMItemBuffer.Date, false) then begin
                        BOMItemBuffer.Init;
                        BOMItemBuffer."Item No." := TransSalesEntry."Item No.";
                        if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
                            BOMItemBuffer.Date := TransSalesEntry.Date
                        else
                            BOMItemBuffer.Date := Statement."Posting Date";
                        BOMItemBuffer.Insert;
                    end;
                end;
                if ((Item."LSC Explode BOM in Statem Post") and (Item."LSC BOM Type" <> Item."LSC BOM Type"::Prepack)) or
                   ((Item."LSC Fuel Item") and (TransSalesEntry."Variant Code" <> ''))
                then begin
                    BOMPostingBuffer[1]."Document No." := DocNumber;
                    if Transaction."To Account" then
                        BOMPostingBuffer[1]."Customer No." := CustomerRec."No.";
                    BOMPostingBuffer[1]."Item No." := TransSalesEntry."Item No.";
                    BOMPostingBuffer[1].Quantity := -TransSalesEntry.Quantity;
                    BOMPostingBuffer[1]."Neg. Qty" := BOMPostingBuffer[1].Quantity <= 0;
                    BOMPostingBuffer[1]."Location Code" := LocCode;
                    if (PostingException.Key <> '') and (PostingException."Transfer Process" = PostingException."Transfer Process"::Transfer) then
                        BOMPostingBuffer[1]."Location Code" := PostingException."Sourcing Location Code";
                    BOMPostingBuffer[1]."Serial No." := '';
                    BOMPostingBuffer[1]."Lot No." := '';
                    BOMPostingBuffer[1]."Expiration Date" := 0D;
                    BOMPostingBuffer[1]."Variant Code" := TransSalesEntry."Variant Code";
                    BOMPostingBuffer[1]."Sales Type" := SalesTypeCode;
                    if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
                        BOMPostingBuffer[1].Date := TransSalesEntry.Date
                    else
                        BOMPostingBuffer[1].Date := Statement."Posting Date";
                    BOMPostingBuffer[1]."Fuel Item" := true;
                    OnBeforeInsertBOMPostingBufferSales(BOMPostingBuffer[1], TransSalesEntry);
                    UpdBOMPostingBuffer;
                end;
            end;

            if (PostingException.Key <> '') and (PostingException."Transfer Process" = PostingException."Transfer Process"::Transfer) then
                ProcessItemAdjustPostBuffer(PostingException);
            OnBeforeInsertItemPostingBufferSales(ItemPostingBuffer[1], TransSalesEntry, Transaction);
            UpdItemPostingBuffer;
        end;
        OnAfterPostItemSales(TransSalesEntry, Transaction, Statement);
    end;

    [Scope('OnPrem')]
    procedure PostIncomeExpLine(DocNumber: Code[20])
    var
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        VATpct: Decimal;
        EntryNo: Integer;
        Len: Integer;
        Handled: Boolean;
    begin
        IncomeExpenseAcc.Get(Store."No.", TransIncomeExpenseEntry."No.");

        OnBeforePostIncomeExpLine(TransIncomeExpenseEntry, Transaction, Statement, DocNumber, PostingBuffer[1], Handled);
        if Handled then
            exit;

        Clear(TableID);
        Clear(No);

        TableID[1] := Database::"LSC Store";
        No[1] := Store."No.";
        TableID[2] := Database::"G/L Account";
        No[2] := IncomeExpenseAcc."G/L Account";
        Len := 2;
        if Transaction."Customer No." <> '' then begin
            TableID[3] := Database::Customer;
            No[3] := Transaction."Customer No.";
            Len := 3;
        end;
        GetDefaultDim(
            TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
            GlobalDimension2Code, Len);

        EntryNo := FindDimensions(TempDimBufNew);
        if EntryNo = 0 then
            EntryNo := InsertDimensions(TempDimBufNew);

        Clear(PostingBuffer[1]);
        PostingBuffer[1].Type := PostingBuffer[1].Type::"G/L Account";
        IncomeExpenseAcc.TestField(IncomeExpenseAcc."G/L Account");
        GLAccount2.Get(IncomeExpenseAcc."G/L Account");
        if Transaction."To Account" then
            PostingBuffer[1]."Customer No." := CustomerRec."No.";
        PostingBuffer[1]."G/L Account" := IncomeExpenseAcc."G/L Account";
        PostingBuffer[1]."Gen. Business Posting Group" := GLAccount2."Gen. Bus. Posting Group";
        PostingBuffer[1]."Gen. Product Posting Group" := GLAccount2."Gen. Prod. Posting Group";
        PostingBuffer[1]."VAT Business Posting Group" := GLAccount2."VAT Bus. Posting Group";
        PostingBuffer[1]."VAT Product Posting Group" := GLAccount2."VAT Prod. Posting Group";
        AssignPostingGrIds(PostingBuffer[1]);
        PostingBuffer[1]."Entry No." := EntryNo;
        PostingBuffer[1]."Department Code" := GlobalDimension1Code;
        PostingBuffer[1]."Project Code" := GlobalDimension2Code;
        PostingBuffer[1]."Currency Code" := Transaction."Trans. Currency";
        PostingBuffer[1]."Document No." := DocNumber;
        if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
            PostingBuffer[1]."VAT Calculation Type" := PostingBuffer[1]."VAT Calculation Type"::"Sales Tax";
            PostingBuffer[1].Amount := TransIncomeExpenseEntry."Net Amount";
            PostingBuffer[1]."VAT Base Amount" := TransIncomeExpenseEntry."Net Amount";
            PostingBuffer[1]."VAT Amount" := TransIncomeExpenseEntry."VAT Amount" +
                                             TransIncomeExpenseEntry."Sales Tax Rounding";
            PostingBuffer[1]."Tax Area Code" := Transaction."Tax Area Code";
            PostingBuffer[1]."Tax Group Code" := TransIncomeExpenseEntry."Tax Group Code";
            PostingBuffer[1]."Tax Liable" := Transaction."Tax Liable";
            PostingBuffer[1]."Tax Exemption No." := Transaction."Tax Exemption No.";
            PostingBuffer[1]."Use Tax" := false;
        end else begin
            PostingBuffer[1]."VAT Calculation Type" := PostingBuffer[1]."VAT Calculation Type"::"Normal VAT";
            VATPostingSetup.Get(GLAccount2."VAT Bus. Posting Group", GLAccount2."VAT Prod. Posting Group");
            VATpct := VATPostingSetup."VAT %" / 100;
            if VATPostingSetup."VAT Calculation Type" <> VATPostingSetup."VAT Calculation Type"::"Normal VAT" then
                VATpct := 0;
            PostingBuffer[1]."VAT Amount" := TransIncomeExpenseEntry."VAT Amount";
            PostingBuffer[1].Amount := TransIncomeExpenseEntry.Amount - PostingBuffer[1]."VAT Amount";
            PostingBuffer[1]."VAT Base Amount" := PostingBuffer[1].Amount;
        end;

        OnBeforeUpdPostingBufferInPostIncomeExpLine2(PostingBuffer[1], TransIncomeExpenseEntry);

        UpdPostingBuffer;
    end;

    local procedure PostCOAmountToBeRefunded(DocNumber: Code[20])
    var
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        VATpct: Decimal;
        EntryNo: Integer;
        Len: Integer;
        RefundPaymentDescription: Label 'Customer Order refund - Customer order %1';
        RefundBalanceAccountMissing: Label '"Customer Order Refund Acc" setup missing for Store %1';
        BalanceAccountMissing: Label '"Customer Order Inc/Expense Acc" setup missing for Store %1';
    begin
        if TransactionStatus."Amount to be Refunded" = 0 then
            exit;

        Store.Get(TransactionStatus."Store No.");
        if not IncomeExpenseAcc.Get(Store."No.", Store."Customer Order Refund Acc") then
            Error('%1', StrSubstNo(RefundBalanceAccountMissing, Store."No."));

        Clear(TableID);
        Clear(No);

        TableID[1] := Database::"LSC Store";
        No[1] := Store."No.";
        TableID[2] := Database::"G/L Account";
        No[2] := IncomeExpenseAcc."G/L Account";
        Len := 2;

        if Transaction."Customer No." <> '' then begin
            TableID[3] := Database::Customer;
            No[3] := Transaction."Customer No.";
            Len := 3;
        end;

        GetDefaultDim(
            TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
            GlobalDimension2Code, Len);

        EntryNo := FindDimensions(TempDimBufNew);
        if EntryNo = 0 then
            EntryNo := InsertDimensions(TempDimBufNew);

        Clear(PostingBuffer[1]);
        PostingBuffer[1].Type := PostingBuffer[1].Type::"G/L Account";
        IncomeExpenseAcc.TestField(IncomeExpenseAcc."G/L Account");
        GLAccount2.Get(IncomeExpenseAcc."G/L Account");
        if Transaction."To Account" then
            PostingBuffer[1]."Customer No." := CustomerRec."No.";
        PostingBuffer[1]."G/L Account" := IncomeExpenseAcc."G/L Account";
        PostingBuffer[1]."Gen. Business Posting Group" := GLAccount2."Gen. Bus. Posting Group";
        PostingBuffer[1]."Gen. Product Posting Group" := GLAccount2."Gen. Prod. Posting Group";
        PostingBuffer[1]."VAT Business Posting Group" := GLAccount2."VAT Bus. Posting Group";
        PostingBuffer[1]."VAT Product Posting Group" := GLAccount2."VAT Prod. Posting Group";
        AssignPostingGrIds(PostingBuffer[1]);
        PostingBuffer[1]."Entry No." := EntryNo;
        PostingBuffer[1]."Department Code" := GlobalDimension1Code;
        PostingBuffer[1]."Project Code" := GlobalDimension2Code;
        PostingBuffer[1]."Currency Code" := Transaction."Trans. Currency";
        PostingBuffer[1]."Document No." := DocNumber;
        PostingBuffer[1]."VAT Calculation Type" := PostingBuffer[1]."VAT Calculation Type"::"Normal VAT";
        VATPostingSetup.Get(GLAccount2."VAT Bus. Posting Group", GLAccount2."VAT Prod. Posting Group");
        VATpct := VATPostingSetup."VAT %" / 100;
        if VATPostingSetup."VAT Calculation Type" <> VATPostingSetup."VAT Calculation Type"::"Normal VAT" then
            VATpct := 0;
        PostingBuffer[1]."VAT Amount" := 0;
        PostingBuffer[1].Amount := -TransactionStatus."Amount to be Refunded";
        PostingBuffer[1]."VAT Base Amount" := PostingBuffer[1].Amount;

        OnBeforeUpdPostingBufferInPostIncomeExpLine(PostingBuffer[1]);

        UpdPostingBuffer;
    end;

    [Scope('OnPrem')]
    procedure PostToCustomer(DocNumber: Code[20])
    var
        BlockedCust: Record Customer;
        SellToCustNo: Code[20];
        TotalAmountPaid: Decimal;
        TempUnblocking: Boolean;
    begin
        OnBeforePostToCustomer(Statement, Transaction);
        if not CustomerRec.Get(Transaction."Customer No.") then
            Error(
              Text031,
              Transaction.FieldCaption("Customer No."), Transaction."Customer No.", CustomerRec.TableCaption);

        SellToCustNo := CustomerRec."No.";

        if CustomerRec."Bill-to Customer No." <> '' then
            if not CustomerRec.Get(CustomerRec."Bill-to Customer No.") then
                Error(
                  Text031,
                  CustomerRec.FieldCaption("Bill-to Customer No."),
                  CustomerRec."Bill-to Customer No.", CustomerRec.TableCaption);

        TempUnblocking := false;
        if (CustomerRec.Blocked <> CustomerRec.Blocked::" ") then begin // temporarily unblocked
            BlockedCust.Blocked := CustomerRec.Blocked;
            CustomerRec.Blocked := CustomerRec.Blocked::" ";
            CustomerRec.Modify;
            TempUnblocking := true;
        end;

        if Transaction."Post as Shipment" then
            AmountToPost := Transaction."Income/Exp. Amount"
        else
            AmountToPost := Transaction."Gross Amount" - Transaction.Rounded + Transaction."Income/Exp. Amount";

        if AmountToPost > 0 then
            DocType := GenJnlLine."Document Type"::"Credit Memo"
        else
            DocType := GenJnlLine."Document Type"::Invoice;

        GenJnlLine.Init;
        GenJnlLine."Posting Date" := Statement."Posting Date";
        GenJnlLine."Document Date" := Transaction.Date;
        GenJnlLine."Reason Code" := '';
        GenJnlLine."Document Type" := DocType;
        GenJnlLine."External Document No." := Statement."Posting No.";
        GenJnlLine."LSC Statement No." := Statement."Posting No.";
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
        GenJnlLine.Validate("Account No.", CustomerRec."No.");
        GenJnlLine.Description := Text042 + Transaction."Receipt No.";
        GenJnlLine."Document No." := DocNumber;
        GenJnlLine.Amount := -1 * AmountToPost;
        GenJnlLine.Validate("Currency Code", Transaction."Trans. Currency");
        if Transaction."Trans. Currency" <> '' then begin
            Currency.Get(Transaction."Trans. Currency");
            CurrencyFactor := CurrencyExchRate.ExchangeRate(GenJnlLine."Posting Date", Transaction."Trans. Currency");
            GenJnlLine.Amount := Round(GenJnlLine.Amount, Currency."Amount Rounding Precision");
            GenJnlLine."Sales/Purch. (LCY)" := -1 *
              Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                Statement."Posting Date", GenJnlLine."Currency Code", Transaction."Net Amount", CurrencyFactor));
            GenJnlLine."Profit (LCY)" := -1 *
              Round(CurrencyExchRate.ExchangeAmtFCYToLCY(
                Statement."Posting Date", GenJnlLine."Currency Code", Transaction."Net Amount" - Transaction."Cost Amount", CurrencyFactor));
        end else begin
            GenJnlLine."Sales/Purch. (LCY)" := -1 * Round(Transaction."Net Amount", GenLedgerSetup."Inv. Rounding Precision (LCY)");
            GenJnlLine."Profit (LCY)" :=
              -1 * Round(Transaction."Net Amount" - Transaction."Cost Amount", GenLedgerSetup."Inv. Rounding Precision (LCY)");
        end;
        GenJnlLine."Bill-to/Pay-to No." := SellToCustNo;
        GenJnlLine."System-Created Entry" := true;
        GenJnlLine."Source Type" := GenJnlLine."Source Type"::Customer;
        GenJnlLine."Source No." := CustomerRec."No.";
        GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
        GenJnlLine."Salespers./Purch. Code" := '';
        GenJnlLine."Payment Discount %" := 0;
        GenJnlLine."LSC Sell-to Contact No." := Transaction."Sell-to Contact No.";

        CreateGenJnlLineDim(
          GenJnlLine,
          DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
          DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
          Database::"LSC Store", Store."No.",
          Database::Customer, CustomerRec."No.", 0, '', Transaction."Sales Type");
        OnBeforeGenJnlPostLine(GenJnlLine, Statement, Transaction);
        GenJnlPostLine.RunWithCheck(GenJnlLine);
        TotalSum := TotalSum + GenJnlLine."Amount (LCY)";

        TotalAmountPaid := TotalPayment;
        if TotalAmountPaid <> 0 then
            PostPaymentToCustomer(DocNumber, CustomerRec."No.", TotalAmountPaid, Transaction."Apply to Doc. No.");

        if Transaction."Customer Order ID" <> '' then
            PostDepositPayments(SellToCustNo);

        if TempUnblocking then begin
            CustomerRec.Get(CustomerRec."No.");
            CustomerRec.Blocked := BlockedCust.Blocked;
            CustomerRec.Modify;
            TempUnblocking := false;
        end;
        OnAfterPostToCustomer(Statement, Transaction);
    end;

    [Scope('OnPrem')]
    procedure PostNegAdjustment(DocNumber: Code[20])
    var
        SalesType2: Record "LSC Sales Type";
        LocCode: Code[10];
    begin
        Item.Get(TransInventoryEntry."Item No.");

        Clear(TableID);
        Clear(No);
        Clear(ItemPostingBuffer[1]);
        ItemPostingBuffer[1].Type := ItemPostingBuffer[1].Type::NegAdjust;
        ItemPostingBuffer[1]."Serial No." := TransInventoryEntry."Serial No.";
        ItemPostingBuffer[1]."Lot No." := TransInventoryEntry."Lot No.";
        ItemPostingBuffer[1]."Expiration Date" := TransInventoryEntry."Expiration Date";
        ItemPostingBuffer[1]."Item No." := TransInventoryEntry."Item No.";

        LocCode := Store."Location Code";
        if TransInventoryEntry."Sales Type" <> '' then
            if SalesType2.Get(TransInventoryEntry."Sales Type") then
                if SalesType2."Location Code" <> '' then
                    LocCode := SalesType2."Location Code";

        ItemPostingBuffer[1]."Location Code" := LocCode;
        ItemPostingBuffer[1]."Document No." := DocNumber;
        ItemPostingBuffer[1].Quantity := TransInventoryEntry.Quantity;
        ItemPostingBuffer[1]."Source No." := TransInventoryEntry."Variant Code";
        if TransInventoryEntry."Variant Code" <> '' then
            ItemPostingBuffer[1]."Source No." := TransInventoryEntry."Variant Code";
        if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
            ItemPostingBuffer[1].Date := TransInventoryEntry.Date
        else
            ItemPostingBuffer[1].Date := Statement."Posting Date";
        ItemPostingBuffer[1]."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";
        OnBeforeUpdateItemPostingBuffer(ItemPostingBuffer[1]);
        OnBeforePostNegAdj(ItemPostingBuffer[1], TransInventoryEntry, Transaction);
        UpdItemPostingBuffer;
    end;

    [Scope('OnPrem')]
    procedure UpdPostingBuffer()
    begin
        if LocalizationExt.IsNALocalizationEnabled then
            if (PostingBuffer[1]."Tax Area Code" <> '') and (PostingBuffer[1]."Tax Group Code" <> '') then begin
                UpdTaxPostingBuffers(PostingBuffer[1]."Document No.");
                //Change the normal entry not to include tax
                PostingBuffer[1]."Tax Area Code" := '';
                PostingBuffer[1]."Tax Group Code" := '';
                PostingBuffer[1]."Tax Liable" := false;
                PostingBuffer[1]."VAT Business Posting Group" := '';
                PostingBuffer[1]."VAT. Bus. Posting Group" := '';
                PostingBuffer[1]."VAT Product Posting Group" := '';
                PostingBuffer[1]."VAT. Prod. Posting Group" := '';
                PostingBuffer[1]."Use Tax" := false;
                PostingBuffer[1]."VAT Amount" := 0;
                PostingBuffer[1]."VAT Base Amount" := 0;
            end;
        PostingBuffer[2] := PostingBuffer[1];
        if PostingBuffer[2].Find then begin
            PostingBuffer[2].Amount := PostingBuffer[2].Amount + PostingBuffer[1].Amount;
            PostingBuffer[2]."VAT Amount" := PostingBuffer[2]."VAT Amount" + PostingBuffer[1]."VAT Amount";

            PostingBuffer[2]."InfoCode Discount Amount" :=
              PostingBuffer[2]."InfoCode Discount Amount" + PostingBuffer[1]."InfoCode Discount Amount";
            if PostingBuffer[1]."InfoCode Discount Account" <> '' then
                PostingBuffer[2]."InfoCode Discount Account" := PostingBuffer[1]."InfoCode Discount Account";

            PostingBuffer[2]."Cust. Discount Amount" :=
              PostingBuffer[2]."Cust. Discount Amount" + PostingBuffer[1]."Cust. Discount Amount";
            if PostingBuffer[1]."Cust. Discount Account" <> '' then
                PostingBuffer[2]."Cust. Discount Account" := PostingBuffer[1]."Cust. Discount Account";

            PostingBuffer[2]."POS Line Disc. Amount" :=
              PostingBuffer[2]."POS Line Disc. Amount" + PostingBuffer[1]."POS Line Disc. Amount";
            if PostingBuffer[1]."POS Line Disc. Account" <> '' then
                PostingBuffer[2]."POS Line Disc. Account" := PostingBuffer[1]."POS Line Disc. Account";

            PostingBuffer[2]."POS Inv. Disc. Amount" :=
              PostingBuffer[2]."POS Inv. Disc. Amount" + PostingBuffer[1]."POS Inv. Disc. Amount";
            if PostingBuffer[1]."POS Inv. Disc. Account" <> '' then
                PostingBuffer[2]."POS Inv. Disc. Account" := PostingBuffer[1]."POS Inv. Disc. Account";

            PostingBuffer[2]."Periodic Disc. Amount" :=
              PostingBuffer[2]."Periodic Disc. Amount" + PostingBuffer[1]."Periodic Disc. Amount";
            if PostingBuffer[1]."Periodic Disc. Account" <> '' then
                PostingBuffer[2]."Periodic Disc. Account" := PostingBuffer[1]."Periodic Disc. Account";

            PostingBuffer[2]."VAT Base Amount" :=
              PostingBuffer[2]."VAT Base Amount" + PostingBuffer[1]."VAT Base Amount";
            if PostingBuffer[2].Amount = 0 then
                PostingBuffer[2].Delete()
            else
                if PostingBuffer[2].Amount = 0 then
                    PostingBuffer[2].Delete()
                else
                    PostingBuffer[2].Modify;
        end else
            PostingBuffer[1].Insert;
    end;

    [Scope('OnPrem')]
    procedure UpdItemPostingBuffer()
    var
        DiscBuffer: Record "LSC Discount Ledger Entry" temporary;
        NextEntryNo: Integer;
    begin
        ItemPostingBuffer[2] := ItemPostingBuffer[1];
        if ItemPostingBuffer[2].Find then begin
            SumItemPostingBuffer(2);
            DiscLedgerMgt.GetCurrDiscBuffer(DiscBuffer);
            DiscLedgerMgt.UpdateDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.", DiscBuffer);
        end else begin
            NextEntryNo := DiscLedgerMgt.GetNextEntryNo;
            ItemPostingBuffer[1]."Discount Entry No." := NextEntryNo;
            ItemPostingBuffer[1].Insert;
            DiscLedgerMgt.GetCurrDiscBuffer(DiscBuffer);
            DiscLedgerMgt.UpdateDiscBuffer(ItemPostingBuffer[1]."Discount Entry No.", DiscBuffer);
        end;
    end;

    [Scope('OnPrem')]
    procedure SumItemPostingBuffer(SumToIndex: Integer)
    begin
        ItemPostingBuffer[SumToIndex].Quantity := ItemPostingBuffer[2].Quantity +
          ItemPostingBuffer[1].Quantity;
        ItemPostingBuffer[SumToIndex].Amount := ItemPostingBuffer[2].Amount +
          ItemPostingBuffer[1].Amount;
        ItemPostingBuffer[SumToIndex]."Cost Amount" := ItemPostingBuffer[2]."Cost Amount" +
          ItemPostingBuffer[1]."Cost Amount";
        ItemPostingBuffer[SumToIndex]."Line Discount Amount" := ItemPostingBuffer[2]."Line Discount Amount" +
          ItemPostingBuffer[1]."Line Discount Amount";
        ItemPostingBuffer[SumToIndex]."Inv. Discount Amount" := ItemPostingBuffer[2]."Inv. Discount Amount" +
          ItemPostingBuffer[1]."Inv. Discount Amount";
        if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then
            ItemPostingBuffer[SumToIndex]."VAT Amount" := ItemPostingBuffer[2]."VAT Amount" +
              ItemPostingBuffer[1]."VAT Amount";
        ItemPostingBuffer[SumToIndex].Modify;
    end;

    [Scope('OnPrem')]
    procedure TestWorkShift(VAR Stmt_p: Record "LSC Statement")
    begin
        WorkShift.GET(Stmt_p."Store No.", Stmt_p."Shift Date", Stmt_p."Shift No.");
        WorkShiftEntry.SETRANGE("Store No.", WorkShift."Store No.");
        WorkShiftEntry.SETRANGE("Shift Date", WorkShift."Shift Date");
        WorkShiftEntry.SETRANGE("Shift No.", WorkShift."Shift No.");
        IF WorkShiftEntry.FINDSET THEN
            REPEAT
                IF WorkShiftEntry."Closing Date" >= Stmt_p."Calculated Date" THEN BEGIN
                    IF WorkShiftEntry."Closing Date" > Stmt_p."Calculated Date" THEN
                        ERROR(Text044);
                    IF WorkShiftEntry."Closing Time" > Stmt_p."Calculated Time" THEN
                        ERROR(Text044);
                END;
            UNTIL WorkShiftEntry.NEXT = 0;
    end;

    [Scope('OnPrem')]
    procedure CreateGenJnlLineDim(var GenJnlLine: Record "Gen. Journal Line"; Type1: Integer; No1: Code[20]; Type2: Integer; No2: Code[20]; Type3: Integer; No3: Code[20]; Type4: Integer; No4: Code[20]; Type5: Integer; No5: Code[20]; pSalesType: Code[20])
    begin
        with GenJnlLine do begin
            TableID[1] := Type1;
            No[1] := No1;
            TableID[2] := Type2;
            No[2] := No2;
            TableID[3] := Type3;
            No[3] := No3;
            TableID[4] := Type4;
            No[4] := No4;
            TableID[5] := Type5;
            No[5] := No5;
            "Shortcut Dimension 1 Code" := '';
            "Shortcut Dimension 2 Code" := '';

            if pSalesType <> '' then begin
                TableID[5] := Database::"LSC Sales Type";
                No[5] := pSalesType;
            end;

            "Dimension Set ID" :=
              DimMgt.GetDefaultDimID(TableID, No, "Source Code", "Shortcut Dimension 1 Code", "Shortcut Dimension 2 Code", 0, 0);
        end;
    end;

    [Scope('OnPrem')]
    procedure CreateItemJnlLineDim(var ItemJnlLine: Record "Item Journal Line"; TableID: array[10] of Integer; No: array[10] of Code[20]; pSalesType: Code[20])
    begin
        with ItemJnlLine do begin
            "Shortcut Dimension 1 Code" := '';
            "Shortcut Dimension 2 Code" := '';
            "Dimension Set ID" :=
              DimMgt.GetDefaultDimID(TableID, No, "Source Code", "Shortcut Dimension 1 Code", "Shortcut Dimension 2 Code", 0, 0);
        end;
    end;

    [Scope('OnPrem')]
    procedure CreateBOMJnlLineDim(var RetailBOMJnlLine: Record "LSC Retail BOM Journal Line"; Type1: Integer; No1: Code[20]; Type2: Integer; No2: Code[20]; pSalesType: Code[20])
    begin
        with RetailBOMJnlLine do begin
            TableID[1] := Type1;
            No[1] := No1;
            TableID[2] := Type2;
            No[2] := No2;
            "Shortcut Dimension 1 Code" := '';
            "Shortcut Dimension 2 Code" := '';

            if pSalesType <> '' then begin
                TableID[3] := Database::"LSC Sales Type";
                No[3] := pSalesType;
            end;
            "Dimension Set ID" :=
              DimMgt.GetDefaultDimID(TableID, No, "Source Code", "Shortcut Dimension 1 Code", "Shortcut Dimension 2 Code", 0, 0);

        end;
    end;

    [Scope('OnPrem')]
    procedure GetDefaultDim(TableID: array[10] of Integer; No: array[10] of Code[20]; SourceCode: Code[20]; var GlobalDim1Code: Code[20]; var GlobalDim2Code: Code[20]; Len: Integer)
    var
        DefaultDimPriority1: Record "Default Dimension Priority";
        DefaultDimPriority2: Record "Default Dimension Priority";
        DefaultDim: Record "Default Dimension";
        NoFilter: array[2] of Code[20];
        i: Integer;
        j: Integer;
        IsHandled: Boolean;
    begin
        OnBeforeGetDefaultDim(Statement, TableID, No, GlobalDim1Code, GlobalDim2Code, Len, Transaction, TransSalesEntry, IsHandled);
        if IsHandled then
            exit;
        GetGLSetup;
        TempDimBufNew.Reset;
        TempDimBufNew.DeleteAll;
        NoFilter[2] := '';
        for i := 1 to Len do begin
            if (TableID[i] <> 0) and (No[i] <> '') then begin
                DefaultDim.SetRange("Table ID", TableID[i]);
                NoFilter[1] := No[i];
                for j := 1 to 2 do begin
                    DefaultDim.SetRange("No.", NoFilter[j]);
                    if DefaultDim.FindSet then begin
                        repeat
                            if DefaultDim."Dimension Value Code" <> '' then begin
                                TempDimBufNew.SetRange("Dimension Code", DefaultDim."Dimension Code");
                                if not TempDimBufNew.FindSet then begin
                                    TempDimBufNew.Init;
                                    TempDimBufNew."Table ID" := DefaultDim."Table ID";
                                    TempDimBufNew."Entry No." := 0;
                                    TempDimBufNew."Dimension Code" := DefaultDim."Dimension Code";
                                    TempDimBufNew."Dimension Value Code" := DefaultDim."Dimension Value Code";
                                    TempDimBufNew.Insert;
                                end else begin
                                    if DefaultDimPriority1.Get(SourceCode, DefaultDim."Table ID") then begin
                                        if DefaultDimPriority2.Get(SourceCode, TempDimBufNew."Table ID") then begin
                                            if DefaultDimPriority1.Priority < DefaultDimPriority2.Priority then begin
                                                TempDimBufNew.Rename(DefaultDim."Table ID", 0, TempDimBufNew."Dimension Code");
                                                TempDimBufNew."Dimension Value Code" := DefaultDim."Dimension Value Code";
                                                TempDimBufNew.Modify;
                                            end;
                                        end else begin
                                            TempDimBufNew.Rename(DefaultDim."Table ID", 0, TempDimBufNew."Dimension Code");
                                            TempDimBufNew."Dimension Value Code" := DefaultDim."Dimension Value Code";
                                            TempDimBufNew.Modify;
                                        end;
                                    end;
                                end;
                                if GLSetupShortcutDimCode[1] = TempDimBufNew."Dimension Code" then
                                    GlobalDim1Code := TempDimBufNew."Dimension Value Code";
                                if GLSetupShortcutDimCode[2] = TempDimBufNew."Dimension Code" then
                                    GlobalDim2Code := TempDimBufNew."Dimension Value Code";
                            end;
                        until DefaultDim.Next = 0;
                    end;
                end;
            end;
        end;
        TempDimBufNew.Reset;
    end;

    local procedure GetGLSetup()
    var
        GLSetup: Record "General Ledger Setup";
    begin
        if not HasGotGLSetup then begin
            GLSetup.Get;
            GLSetupShortcutDimCode[1] := GLSetup."Shortcut Dimension 1 Code";
            GLSetupShortcutDimCode[2] := GLSetup."Shortcut Dimension 2 Code";
            GLSetupShortcutDimCode[3] := GLSetup."Shortcut Dimension 3 Code";
            GLSetupShortcutDimCode[4] := GLSetup."Shortcut Dimension 4 Code";
            GLSetupShortcutDimCode[5] := GLSetup."Shortcut Dimension 5 Code";
            GLSetupShortcutDimCode[6] := GLSetup."Shortcut Dimension 6 Code";
            GLSetupShortcutDimCode[7] := GLSetup."Shortcut Dimension 7 Code";
            GLSetupShortcutDimCode[8] := GLSetup."Shortcut Dimension 8 Code";
            HasGotGLSetup := true;
        end;
    end;

    [Scope('OnPrem')]
    procedure InsertDimensions(var DimBuf: Record "Dimension Buffer"): Integer
    var
        NewEntryNo: Integer;
    begin
        if DimBuf.FindSet then begin
            if TempDimBufPost.FindLast then
                NewEntryNo := TempDimBufPost."Entry No." + 1
            else
                NewEntryNo := 1;
            InsertDimensionsUsingEntryNo(DimBuf, NewEntryNo);
            exit(NewEntryNo);
        end else
            exit(0);
    end;

    [Scope('OnPrem')]
    procedure InsertDimensionsUsingEntryNo(var DimBuf: Record "Dimension Buffer"; EntryNo: Integer)
    begin
        if DimBuf.FindSet then
            repeat
                TempDimBufPost.Init;
                TempDimBufPost := DimBuf;
                TempDimBufPost."Entry No." := EntryNo;
                TempDimBufPost.Insert;
                TmpInteger.Number := EntryNo;
                if TmpInteger.Insert then;
            until DimBuf.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure FindDimensions(var DimBuf: Record "Dimension Buffer"): Integer
    var
        Match: Boolean;
        Found: Boolean;
        EndOfDimBuf: Boolean;
        EndOfTempDimBuf: Boolean;
        FinalEndOfTempDimBuf: Boolean;
        IsHandled: boolean;
    begin
        OnBeforeFindDimensions(Statement, DimBuf, TempDimBufPost, IsHandled);
        If IsHandled then
            exit(0);
        if DimBuf.IsEmpty then
            exit(0);

        TempDimBufPost.Reset;
        if TempDimBufPost.IsEmpty then
            exit(0);

        if TmpInteger.FindSet then
            repeat
                TempDimBufPost.SetRange("Entry No.", TmpInteger.Number);
                DimBuf.FindSet;
                TempDimBufPost.FindSet;
                repeat
                    Match :=
                      (TempDimBufPost."Dimension Code" = DimBuf."Dimension Code") and
                      (TempDimBufPost."Dimension Value Code" = DimBuf."Dimension Value Code");
                    if Match then begin
                        EndOfTempDimBuf := TempDimBufPost.Next = 0;
                        EndOfDimBuf := DimBuf.Next = 0;
                    end;
                until EndOfTempDimBuf or EndOfDimBuf or not Match;

                Found := Match and EndOfDimBuf and EndOfTempDimBuf;
                if Found then
                    exit(TempDimBufPost."Entry No.")
                else begin
                    FinalEndOfTempDimBuf := TmpInteger.Next = 0;
                end;
            until FinalEndOfTempDimBuf;
        exit(0);
    end;

    [Scope('OnPrem')]
    procedure GetDimensions(EntryNo: Integer; var DimBuf: Record "Dimension Buffer"): Boolean
    begin
        TempDimBufPost.SetRange("Entry No.", EntryNo);
        if not TempDimBufPost.FindSet then
            exit(false)
        else
            repeat
                DimBuf.Init;
                DimBuf := TempDimBufPost;
                DimBuf.Insert;
            until TempDimBufPost.Next = 0;
        exit(true);
    end;

    [Scope('OnPrem')]
    procedure UpdBOMPostingBuffer()
    begin
        BOMPostingBuffer[2] := BOMPostingBuffer[1];
        if BOMPostingBuffer[2].Find then
            SumBOMPostingBuffer(2)
        else
            BOMPostingBuffer[1].Insert;
    end;

    [Scope('OnPrem')]
    procedure SumBOMPostingBuffer(SumToIndex: Integer)
    begin
        BOMPostingBuffer[SumToIndex].Quantity := BOMPostingBuffer[2].Quantity + BOMPostingBuffer[1].Quantity;
        BOMPostingBuffer[SumToIndex].Modify;
    end;

    [Scope('OnPrem')]
    procedure MakeOrder(PostGLEntries: Boolean)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShpHdr: Record "Sales Shipment Header";
        BlockedCust: Record Customer;
        Location: Record Location;
        SalesOrderItemBuffer: Record "LSC Item Finder Set" temporary;
        SalesPost: Codeunit "Sales-Post";
        DocumentNo: Code[20];
        SalesTypeCode: Code[20];
        LineNo: Integer;
        ShowCreditLimitWarnings: Integer;
        TempCustUnblocking: Boolean;
        SkipPostSalesHeader: Boolean;
        TempChangeShowCreditLimiitWarning: Boolean;
    begin
        if TransSalesEntry.FindFirst then
            TransSalesEntryStatus.Get(TransSalesEntry."Store No.",
              TransSalesEntry."POS Terminal No.",
              TransSalesEntry."Transaction No.",
              TransSalesEntry."Line No.")
        else
            exit;

        OnBeforeMakeOrder(TransSalesEntry, Transaction, Statement);
        if TransSalesEntryStatus.Status = TransSalesEntryStatus.Status::"Items Posted" then begin
            SalesShpHdr.SetCurrentKey("Sell-to Customer No.", "External Document No.");
            SalesShpHdr.SetRange("Sell-to Customer No.", Transaction."Customer No.");
            DocumentNo := CreateDocNo(Transaction."Store No.",
              Transaction."POS Terminal No.",
              Transaction."Transaction No.");
            SalesShpHdr.SetRange("External Document No.", DocumentNo);
            if SalesShpHdr.FindSet then
                repeat
                    if SalesShpHdr."LSC Statement No." <> '' then begin
                        if glUndoItemPosting then
                            SalesShpHdr."LSC Statement No." := DocumentNo
                        else
                            SalesShpHdr."LSC Statement No." := Statement."Posting No.";
                    end;
                    SalesShpHdr.Modify;
                until SalesShpHdr.Next = 0;
        end else
            if TransSalesEntry.FindFirst then begin
                if CustomerRec.Blocked <> CustomerRec.Blocked::" " then begin // temporarily unblocked
                    BlockedCust.Blocked := CustomerRec.Blocked;
                    CustomerRec.Blocked := CustomerRec.Blocked::" ";
                    CustomerRec.Modify;
                    TempCustUnblocking := true;
                end;

                TempChangeShowCreditLimiitWarning := false;
                SalesReceivablesSetup.Get;
                if SalesReceivablesSetup."Credit Warnings" <> SalesReceivablesSetup."Credit Warnings"::"No Warning" then begin
                    ShowCreditLimitWarnings := SalesReceivablesSetup."Credit Warnings";
                    SalesReceivablesSetup."Credit Warnings" := SalesReceivablesSetup."Credit Warnings"::"No Warning";
                    TempChangeShowCreditLimiitWarning := true;
                    SalesReceivablesSetup.Modify;
                end;

                SalesHeader.Init;

                if Transaction."Sale Is Return Sale" then
                    SalesHeader."Document Type" := SalesHeader."Document Type"::"Return Order"
                else
                    SalesHeader."Document Type" := SalesHeader."Document Type"::Order;

                if BackOfficeSetup."Item Posting Date" = BackOfficeSetup."Item Posting Date"::"Transaction Date" then
                    SalesHeader.Validate("Posting Date", Transaction.Date)
                else
                    SalesHeader.Validate("Posting Date", Statement."Posting Date");
                if LocalizationExt.IsNALocalizationEnabled then
                    SalesHeader."No." := Transaction."Customer No.";
                SalesHeader.Validate("Sell-to Customer No.", Transaction."Customer No.");
                if LocalizationExt.IsNALocalizationEnabled then
                    SalesHeader."No." := '';
                if not SalesHeader.Insert(true) then begin
                    DocumentNo := CreateDocNo(Transaction."Store No.",
                      Transaction."POS Terminal No.",
                      Transaction."Transaction No.");
                    SalesHeader.Validate("No.", DocumentNo);
                    SalesHeader.Insert(true);
                end;
                DocumentNo := CreateDocNo(Transaction."Store No.",
                  Transaction."POS Terminal No.",
                  Transaction."Transaction No.");
                SalesHeader."External Document No." := DocumentNo;
                SalesHeader.Validate("Location Code", Store."Location Code");
                SalesHeader.Validate("Shortcut Dimension 1 Code", Store."Global Dimension 1 Code");

                SalesTypeCode := Transaction."Sales Type";
                if TransSalesEntry."Sales Type" <> '' then
                    SalesTypeCode := TransSalesEntry."Sales Type";

                FindSalesType(SalesTypeCode);

                if SalesTypes."Global Dimension 1 Code" <> '' then
                    SalesHeader.Validate("Shortcut Dimension 1 Code", SalesTypes."Global Dimension 1 Code");

                if SalesTypes."Global Dimension 2 Code" <> '' then
                    SalesHeader.Validate("Shortcut Dimension 2 Code", SalesTypes."Global Dimension 2 Code")
                else
                    if Store."Global Dimension 2 Code" <> '' then
                        SalesHeader.Validate("Shortcut Dimension 2 Code", Store."Global Dimension 2 Code");

                SalesHeader."Prices Including VAT" := true;
                SalesHeader.Invoice := false;

                if Transaction."Sale Is Return Sale" then
                    SalesHeader.Receive := true
                else
                    SalesHeader.Ship := true;

                SalesHeader."LSC Statement No." := Statement."Posting No.";
                if SalesHeader."Currency Code" <> Transaction."Trans. Currency" then
                    SalesHeader.Validate("Currency Code", Transaction."Trans. Currency");
                if UseSalesTax and LocalizationExt.IsNALocalizationEnabled then begin
                    SalesHeader."Tax Area Code" := Transaction."Tax Area Code";
                    SalesHeader."Tax Liable" := Transaction."Tax Liable";
                end;
                OnBeforeModifySalesHeaderInMakeOrder(SalesHeader, Transaction, Statement);
                SalesHeader.Modify;

                TransPostingFunctions.ClearItemNoBuffer;
                LineNo := 0;
                repeat
                    Item.Get(TransSalesEntry."Item No.");
                    TransPostingFunctions.SetItemBlockReserve(Item."No.");
                    TransPostingFunctions.SetItemNoInBuffer(Item."No.");
                    Clear(SalesLine);
                    SalesLine."Document Type" := SalesHeader."Document Type";
                    SalesLine."Document No." := SalesHeader."No.";
                    LineNo += 10000;
                    SalesLine."Line No." := LineNo;
                    SalesLine.Insert(true);
                    SalesLine.Type := SalesLine.Type::Item;
                    SalesLine.Validate("No.", TransSalesEntry."Item No.");
                    SalesLine."Cross-Reference No." := CopyStr(TransSalesEntry."Barcode No.", 1, MaxStrLen(SalesLine."Cross-Reference No."));
                    SalesLine.Validate("Variant Code", TransSalesEntry."Variant Code");
                    if SalesLine.IsInventoriableItem() then
                        SalesLine.Validate("Location Code", Store."Location Code");
                    if LocalizationExt.IsNALocalizationEnabled then begin
                        SalesLine."Tax Area Code" := SalesHeader."Tax Area Code";
                        SalesLine."Tax Liable" := SalesHeader."Tax Liable";
                        SalesLine."Tax Group Code" := TransSalesEntry."Tax Group Code";
                    end;
                    if TransSalesEntry."Unit of Measure" <> '' then
                        SalesLine.Validate("Unit of Measure Code", TransSalesEntry."Unit of Measure")
                    else
                        SalesLine.Validate("Unit of Measure Code", '');

                    if Transaction."Sale Is Return Sale" then
                        TransSalesEntry.Quantity := -TransSalesEntry.Quantity;
                    if TransSalesEntry."UOM Quantity" <> 0 then begin
                        SalesLine.Validate(Quantity, -TransSalesEntry."UOM Quantity");
                        SalesLine.Validate("Unit Price", TransSalesEntry.Price * TransSalesEntry.Quantity / TransSalesEntry."UOM Quantity");
                    end else begin
                        SalesLine.Validate(Quantity, -TransSalesEntry.Quantity);
                        SalesLine.Validate("Unit Price", TransSalesEntry.Price);
                    end;
                    if Transaction."Sale Is Return Sale" then
                        TransSalesEntry.Quantity := -TransSalesEntry.Quantity;

                    SalesLine.Validate("Line Discount Amount", TransSalesEntry."Discount Amount" - TransSalesEntry."Total Discount");
                    SalesLine.Validate("Inv. Discount Amount", TransSalesEntry."Total Discount");
                    SalesLine."LSC Offer No." := TransSalesEntry."Periodic Disc. Group";
                    SalesLine."LSC Promotion No." := TransSalesEntry."Promotion No.";
                    OnBeforeModifySalesLine(SalesLine, Transaction, TransSalesEntry);

                    if TransSalesEntry."Serial No." <> '' then
                        TransPostingFunctions.AddSalesLineSerialNoTracking(SalesHeader, SalesLine, TransSalesEntry."Serial No.", TransSalesEntry."Expiration Date");

                    if TransSalesEntry."Lot No." <> '' then
                        TransPostingFunctions.AddSalesLineLotNoTracking(SalesHeader, SalesLine, TransSalesEntry."Lot No.", TransSalesEntry."Expiration Date");

                    SalesLine.Modify(true);

                    OnAfterSalesLineModify(SalesLine, TransSalesEntry);

                    InsertSalesLineDiscEntry(TransSalesEntry, SalesLine);
                    TransPostingFunctions.ResetItemBlockReserve;
                until TransSalesEntry.Next = 0;

                SkipPostSalesHeader := false;
                if Transaction."Sale Is Return Sale" then
                    if Location.Get(SalesHeader."Location Code") then
                        if Location."Require Receive" then begin
                            if not SkipPostSalesHeader then begin
                                SkipPostSalesHeader := true;
                                ShowReturnOrderMsg := true;
                                FirstReturnOrderNo := SalesHeader."No.";
                            end;
                            LastReturnOrderNo := SalesHeader."No.";
                        end;

                if not SkipPostSalesHeader then begin
                    TransPostingFunctions.GetItemNoBuffer(SalesOrderItemBuffer);
                    SalesOrderItemBuffer.Reset;
                    if SalesOrderItemBuffer.FindSet then
                        repeat
                            TransPostingFunctions.SetItemBlockReserve(SalesOrderItemBuffer."Item No.");
                        until SalesOrderItemBuffer.Next = 0;
                    Clear(SalesPost);
                    SalesPost.SetSuppressCommit(true);
                    SalesPost.Run(SalesHeader);
                    TransPostingFunctions.ResetItemBlockReserve;
                    TransPostingFunctions.ClearItemNoBuffer;
                end;

                if TempCustUnblocking then begin
                    CustomerRec.Get(CustomerRec."No.");
                    CustomerRec.Blocked := BlockedCust.Blocked;
                    CustomerRec.Modify;
                    TempCustUnblocking := false;
                end;
                if TempChangeShowCreditLimiitWarning then begin
                    SalesReceivablesSetup.Get;
                    SalesReceivablesSetup."Credit Warnings" := ShowCreditLimitWarnings;
                    SalesReceivablesSetup.Modify;
                end;
                OnAfterMakeOrder(SalesHeader, Transaction, Statement);
            end;
    end;

    [Scope('OnPrem')]
    procedure PostItem()
    var
        Cust: Record Customer;
        RBOtoAdjust: Record "LSC Adj. Item Ledgers for RBO";
        DiscBuffer: Record "LSC Discount Ledger Entry" temporary;
        AdjustedUnitCost: Decimal;
        i: Integer;
    begin
        CompressItemPostingBuffer;
        OnBeforePostItem(ItemPostingBuffer[1], Statement);
        ItemPostingBuffer[1].Quantity := Round(ItemPostingBuffer[1].Quantity, 0.00001);

        if ItemPostingBuffer[1].Quantity <> 0 then begin
            Item.Get(ItemPostingBuffer[1]."Item No.");
            if (Format(Item."LSC Lifecycle Length") <> '') and
               (Item."LSC Lifecycle Starting Date" = 0D) then begin
                Item."LSC Lifecycle Starting Date" := Today;
                Item."LSC Lifecycle Ending Date" := CalcDate(Item."LSC Lifecycle Length", Today);
                Item.Modify;
            end;
            TransPostingFunctions.SetItemBlockReserve(Item."No.");
            Clear(ItemJnlLine);
            ItemJnlLine.Init;
            ItemJnlLine."Item No." := ItemPostingBuffer[1]."Item No.";
            ItemJnlLine."Variant Code" := ItemPostingBuffer[1]."Source No.";
            ItemJnlLine."Posting Date" := ItemPostingBuffer[1].Date;
            ItemJnlLine."Document Date" := Statement."Posting Date";
            if Item.Type = Item.Type::Inventory then
                ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Sale)
            else
                ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Sale;
            ItemJnlLine."Document No." := ItemPostingBuffer[1]."Document No.";
            ItemJnlLine."External Document No." := ItemPostingBuffer[1]."Document No.";
            ItemJnlLine.Description := Item.Description;
            ItemJnlLine."Location Code" := ItemPostingBuffer[1]."Location Code";
            ItemJnlLine."Inventory Posting Group" := Item."Inventory Posting Group";
            ItemJnlLine."Source Posting Group" := '';
            if Item."Base Unit of Measure" <> '' then begin
                ItemJnlLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
                ItemJnlLine.Validate(Quantity, ItemPostingBuffer[1].Quantity);
            end else begin
                ItemJnlLine."Unit of Measure Code" := '';
                ItemJnlLine."Qty. per Unit of Measure" := 1;
                ItemJnlLine.Validate("Quantity (Base)", ItemPostingBuffer[1].Quantity);
            end;
            ItemJnlLine."LSC BO Doc. No." := Statement."Posting No.";
            if Statement."Posting No." = '' then
                ItemJnlLine."LSC BO Doc. No." := Statement."No.";
            ItemJnlLine."Unit Amount" := Round(ItemPostingBuffer[1].Amount / ItemPostingBuffer[1].Quantity);
            ItemJnlLine.Amount := ItemPostingBuffer[1].Amount;
            ItemJnlLine."Discount Amount" := ItemPostingBuffer[1]."Line Discount Amount" + ItemPostingBuffer[1]."Inv. Discount Amount";
            ItemJnlLine."Salespers./Purch. Code" := ItemPostingBuffer[1]."Salesperson Code";
            ItemJnlLine."Source Code" := BackOfficeSetup."Source Code";
            ItemJnlLine."Gen. Bus. Posting Group" := ItemPostingBuffer[1]."Gen. Bus. Posting Group";
            ItemJnlLine."Gen. Prod. Posting Group" := ItemPostingBuffer[1]."Gen. Prod. Posting Group";
            ItemJnlLine."LSC Offer No." := ItemPostingBuffer[1]."Offer No.";
            ItemJnlLine."LSC Promotion No." := ItemPostingBuffer[1]."Promotion No.";

            ItemJnlLine."Expiration Date" := ItemPostingBuffer[1]."Expiration Date";
            if (ItemPostingBuffer[1]."Serial No." <> '') or (ItemPostingBuffer[1]."Lot No." <> '') then
                TransPostingFunctions.AddSerialNoAndLotNoTracking(ItemJnlLine, ItemPostingBuffer[1]."Serial No.", ItemPostingBuffer[1]."Lot No.", ItemPostingBuffer[1]."Expiration Date");

            if ItemPostingBuffer[1]."Customer No." <> '' then begin
                ItemJnlLine."Source No." := ItemPostingBuffer[1]."Customer No.";
                ItemJnlLine."Source Type" := ItemJnlLine."Source Type"::Customer;
            end;
            i := 1;
            Clear(TableID);
            Clear(No);
            TableID[i] := Database::Item;
            No[i] := ItemJnlLine."Item No.";
            i += 1;
            TableID[i] := Database::"LSC Store";
            No[i] := Store."No.";
            if ItemPostingBuffer[1]."Customer No." <> '' then begin
                i += 1;
                TableID[i] := Database::Customer;
                No[i] := ItemPostingBuffer[1]."Customer No.";
            end;
            if ItemPostingBuffer[1]."Salesperson Code" <> '' then begin
                i += 1;
                TableID[i] := Database::"Salesperson/Purchaser";
                No[i] := ItemPostingBuffer[1]."Salesperson Code";
            end;
            if ItemPostingBuffer[1]."Sales Type" <> '' then begin
                i += 1;
                TableID[i] := Database::"LSC Sales Type";
                No[i] := ItemPostingBuffer[1]."Sales Type";
            end;
            CreateItemJnlLineDim(ItemJnlLine, TableID, No, ItemPostingBuffer[1]."Sales Type");

            DiscLedgerMgt.GetDiscBuffer(ItemPostingBuffer[1]."Discount Entry No.", DiscBuffer);
            RetailItemJnlExt.SetDiscLedgerBuffer(ItemJnlLine, DiscBuffer);
            OnBeforeItemJnlLinePostLine(ItemJnlLine, Statement, ItemPostingBuffer[1]);
            ItemJnlPostLine.RunWithCheck(ItemJnlLine);
            OnAfterItemJnlLinePostLine(ItemJnlLine, Statement);
            RetailItemJnlExt.ClearDiscLedgerBuffer(ItemJnlLine);
            TransPostingFunctions.ResetItemBlockReserve;
            if BackOfficeSetup."Update Cost Amount" then begin
                if not RBOtoAdjust.FindLast then
                    RBOtoAdjust."Entry No." := 0;
                RBOtoAdjust.Init;
                RBOtoAdjust."Entry No." += 1;
                RBOtoAdjust."Item Ledger No." := RetailItemJnlExt.GetItemLedgEntryNo;
                RBOtoAdjust."Item No." := ItemJnlLine."Item No.";
                RBOtoAdjust."Adjusted Qty." := -ItemJnlLine.Quantity;
                AdjustedUnitCost := (ItemPostingBuffer[1]."Cost Amount" / ItemPostingBuffer[1].Quantity) - ItemJnlLine."Unit Cost";
                RBOtoAdjust."Adjusted Amount" := AdjustedUnitCost * ItemPostingBuffer[1].Quantity;
                RBOtoAdjust."RBO No." := CopyStr(ItemJnlLine."External Document No.", 1, MaxStrLen(RBOtoAdjust."RBO No."));
                RBOtoAdjust.Date := Today;
                RBOtoAdjust.Time := Time;
                if RBOtoAdjust."Adjusted Amount" <> 0 then
                    RBOtoAdjust.Insert;
            end;
        end;
    end;

    [Scope('OnPrem')]
    procedure PostBOM()
    begin
        if not BOMPostingBuffer[1]."Neg. Qty" then
            if BOMPostingBuffer[2].Get(
              BOMPostingBuffer[1]."Document No.", BOMPostingBuffer[1]."Customer No.",
              BOMPostingBuffer[1]."Item No.", BOMPostingBuffer[1]."Variant Code",
              BOMPostingBuffer[1].Date, true)
            then
                if BOMPostingBuffer[1].Quantity + BOMPostingBuffer[2].Quantity <> 0 then begin
                    SumBOMPostingBuffer(1);
                    BOMPostingBuffer[2].Delete;
                end;

        Clear(RetailBOMJnlLine);
        RetailBOMJnlLine.Init;
        RetailBOMJnlLine."Fuel Item" := BOMPostingBuffer[1]."Fuel Item";
        RetailBOMJnlLine.Validate("Item No.", BOMPostingBuffer[1]."Item No.");
        if BOMPostingBuffer[1]."Variant Code" <> '' then
            RetailBOMJnlLine.Validate("Variant Code", BOMPostingBuffer[1]."Variant Code");
        RetailBOMJnlLine.Validate(Quantity, BOMPostingBuffer[1].Quantity);
        RetailBOMJnlLine."Posting Date" := BOMPostingBuffer[1].Date;
        RetailBOMJnlLine."Document No." := BOMPostingBuffer[1]."Document No.";
        RetailBOMJnlLine."Location Code" := BOMPostingBuffer[1]."Location Code";
        RetailBOMJnlLine."Source Code" := BackOfficeSetup."Source Code";
        RetailBOMJnlLine."Statement No." := Statement."Posting No.";
        OnBeforeRetailBOMJnlPostLine(RetailBOMJnlLine, BOMPostingBuffer[1]);
        PostBOMRecursive(RetailBOMJnlLine);
    end;

    [Scope('OnPrem')]
    procedure PostBOMRecursive(pRetailBOMJnlLine: Record "LSC Retail BOM Journal Line")
    var
        RetailBOMJnlLineRe: Record "LSC Retail BOM Journal Line";
        ItemLoc: Record Item;
        BOMComp: Record "BOM Component";
        UOMMgmt: Codeunit "Unit of Measure Management";
    begin
        BOMComp.Reset;
        BOMComp.SetRange("Parent Item No.", pRetailBOMJnlLine."Item No.");
        if BOMComp.FindSet then
            repeat
                if (BOMComp.Type = BOMComp.Type::Item) and (BOMComp."No." <> '') then begin
                    ItemLoc.Get(BOMComp."No.");
                    ItemLoc.CalcFields("Assembly BOM");
                    if (ItemLoc."Assembly BOM") and (ItemLoc."LSC Explode BOM in Statem Post") then begin
                        RetailBOMJnlLineRe := pRetailBOMJnlLine;
                        RetailBOMJnlLineRe.Validate("Item No.", BOMComp."No.");
                        if BOMComp."Variant Code" <> '' then
                            RetailBOMJnlLineRe."Variant Code" := BOMComp."Variant Code";
                        RetailBOMJnlLineRe.Validate(Quantity, pRetailBOMJnlLine.Quantity * BOMComp."Quantity per" * UOMMgmt.GetQtyPerUnitOfMeasure(ItemLoc, BOMComp."Unit of Measure Code"));
                        OnBeforeRetailBOMJnlPostBOMCompLine(RetailBOMJnlLineRe, Store);
                        PostBOMRecursive(RetailBOMJnlLineRe);
                    end;
                end;
            until BOMComp.Next = 0;

        CreateBOMJnlLineDim(
          pRetailBOMJnlLine, Database::Item, pRetailBOMJnlLine."Item No.", Database::"LSC Store", Store."No.", BOMPostingBuffer[1]."Sales Type");
        RetailBOMJnlPostLine.RunWithCheck(pRetailBOMJnlLine);
    end;

    [Scope('OnPrem')]
    procedure RunItemPosting(locStatement: Record "LSC Statement"; UndoItemPosting: Boolean)
    var
        ItemPostingBuffer_RV: Record "LSC Item Posting Buffer";
        ItemPostingBuffer_Temp: Record "LSC Item Posting Buffer";
        UpdateAnalysisView: Codeunit "Update Analysis View";
        DocumentNo: Code[20];
    begin
        LockTimeout(false);
        OnBeforeRunItemPosting(Statement, UndoItemPosting);
        TransPostingFunctions.InitFunction;

        ItemPostingBuffer[1].DeleteAll;
        BOMPostingBuffer[1].DeleteAll;
        ItemAdjustPostBuffer[1].DeleteAll;

        Statement := locStatement;
        glUndoItemPosting := UndoItemPosting;
        Clear(ItemJnlPostLine);

        if UndoItemPosting then
            Error(Text047);

        TransactionStatus.Reset;
        TransactionStatus.SetCurrentKey("Statement No.");
        TransactionStatus.SetRange("Statement No.", Statement."No.");
        if TransactionStatus.IsEmpty then
            Error(Text014);

        if (not UndoItemPosting) and (not locStatement."Skip Confirmation") then
            "Cust/ItemChecks"(Statement, TRUE);

        Store.Get(locStatement."Store No.");
        Store.TestField("Store Gen. Bus. Post. Gr.");
        BackOfficeSetup.Get;
        CompletePost := false;

        OpenTablesBuffers();
        if TransactionStatus.FindSet then
            repeat
                if TransactionStatus.Status < TransactionStatus.Status::"Items Posted" then begin
                    Transaction.Get(TransactionStatus."Store No.", TransactionStatus."POS Terminal No.", TransactionStatus."Transaction No.");
                    if Transaction."To Account" then begin
                        if not CustomerRec.Get(Transaction."Customer No.") then
                            Error(
                              Text031,
                              Transaction.FieldCaption("Customer No."), Transaction."Customer No.", CustomerRec.TableCaption);
                        TransSalesEntry.SetRange("Store No.", Transaction."Store No.");
                        TransSalesEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                        TransSalesEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                        if Transaction."Post as Shipment" then
                            MakeOrder(false)
                        else begin
                            if TransSalesEntry.FindSet then
                                repeat
                                    DocumentNo := CreateDocNo(TransSalesEntry."Store No.",
                                      TransSalesEntry."POS Terminal No.",
                                      TransSalesEntry."Transaction No.");
                                    PostItemSales(DocumentNo, false);
                                until TransSalesEntry.Next = 0;
                        end;
                    end else begin
                        TransSalesEntry.SetRange("Store No.", Transaction."Store No.");
                        TransSalesEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                        TransSalesEntry.SetRange("Transaction No.", Transaction."Transaction No.");
                        if TransSalesEntry.FindSet then
                            repeat
                                if locStatement."Posting No." = '' then
                                    PostItemSales(locStatement."No.", false)
                                else
                                    PostItemSales(locStatement."Posting No.", false);
                            until TransSalesEntry.Next = 0;
                    end;
                    if not UndoItemPosting then begin
                        TransactionStatus.Status := TransactionStatus.Status::"Items Posted";
                        TransStatusToBuffer(TransactionStatus);
                    end;
                end;
            until TransactionStatus.Next = 0;

        if BOMPostingBuffer[1].FindSet then
            repeat
                PostBOM;
            until BOMPostingBuffer[1].Next = 0;

        ItemAdjustPostBuffer[1].Reset;
        if ItemAdjustPostBuffer[1].FindSet then
            repeat
                PostItemAdjustment;
            until ItemAdjustPostBuffer[1].Next = 0;
        TransPostingFunctions.InsertInvAdjustEntry(ItemAdjustPostBuffer[1]);

        if ItemPostingBuffer[1].FindSet then
            repeat
                if (ItemPostingBuffer[1]."Serial No." <> '') or (ItemPostingBuffer[1]."Lot No." <> '') then begin
                    CompressItemPostingBuffer;
                    if OkToPostDirect(ItemPostingBuffer[1]) then
                        PostItem
                    else
                        if FindReversePosting(ItemPostingBuffer[1], ItemPostingBuffer_RV) then begin
                            ItemPostingBuffer_Temp := ItemPostingBuffer[1];
                            ItemPostingBuffer[1] := ItemPostingBuffer_RV;
                            PostItem();
                            ItemPostingBuffer[1] := ItemPostingBuffer_Temp;
                            PostItem;
                        end else
                            PostItem;
                    ItemPostingBuffer[1].Delete;
                end else
                    PostItem;
            until ItemPostingBuffer[1].Next = 0;

        FlushTablesBuffers();

        if not UndoItemPosting then begin
            locStatement.Status := locStatement.Status::"Sales Entries Posted";
            if not CompletePost then
                locStatement.Modify(true)
            else
                locStatement.Modify;
        end;
        Clear(glUndoItemPosting);

        UpdateAnalysisView.UpdateAll(0, true);
        if not RunningFromBatchPosting then
            if not UndoItemPosting then
                Message(Text057, Statement.TableCaption);
        OnAfterRunItemPosting(Statement, UndoItemPosting);
    end;

    [Scope('OnPrem')]
    procedure "Cust/ItemChecks"(VAR Statement_p: Record "LSC Statement"; CheckBlockedCustomer: Boolean)
    begin
        if Statement_p."No. of Blocked Items" > 0 then begin
            Txt := StrSubstNo(
              Text006 +
              Text007,
              Statement_p."No. of Blocked Items", Item.TableCaption, Statement_p.TableCaption, Transaction.TableCaption);
            if not Confirm(Txt, false) then
                Error(Text002);
        end;

        if Statement_p."No. of Blocked Cust." > 0 then begin
            Txt := StrSubstNo(
              Text006 +
              Text007,
              Statement_p."No. of Blocked Cust.", CustomerRec.TableCaption, Statement_p.TableCaption, Transaction.TableCaption);
            if not Confirm(Txt, false) then
                Error(Text002);
        end;
    end;

    PROCEDURE PrePostingChecks(VAR Stmt_p: Record "LSC Statement"; VAR Store_p: Record "LSC Store"; RunningFromBatchPosting_p: Boolean): Boolean;
    VAR
        TransactionStatus_l: Record "LSC Transaction Status";
        Transaction_l: Record "LSC Transaction Header";
        StatementLine_l: Record "LSC Statement Line";
        SafeStatementLine_l: Record "LSC Safe Statement Line";
        TransCounter: Integer;
        IsHandled: Boolean;
    BEGIN
        IF NOT RunningFromBatchPosting_p THEN
            IF Stmt_p."Closing Method" = Stmt_p."Closing Method"::"Date and Time" THEN
                IF Stmt_p."Posting Date" - Stmt_p."Trans. Ending Date" > 30 THEN
                    IF NOT CONFIRM(Text000 + Text001, FALSE, Stmt_p.FIELDCAPTION("Posting Date"), Stmt_p.FIELDCAPTION("Trans. Ending Date")) THEN
                        ERROR(Text002);

        //Check for Sales/Pmt differences
        IF Stmt_p."Trans. w/ Sale/Pmt. Diff." > 0 THEN BEGIN
            TransactionStatus_l.SETCURRENTKEY("Statement No.");
            TransactionStatus_l.SETRANGE("Statement No.", Stmt_p."No.");
            TransactionStatus_l.SETRANGE("Sale/Pmt. Difference", TRUE);
            IF TransactionStatus_l.FINDSET THEN
                REPEAT
                    Transaction_l.GET(TransactionStatus_l."Store No.", TransactionStatus_l."POS Terminal No.", TransactionStatus_l."Transaction No.");
                    IF Transaction_l."Trans. Sale/Pmt. Diff." > Store_p."Allowed Diff. in Trans." THEN
                        TransCounter := TransCounter + 1;
                UNTIL TransactionStatus_l.NEXT = 0;
            IF TransCounter > 0 THEN BEGIN
                Txt := STRSUBSTNO(
                  Text008 +
                  Text001,
                  TransCounter, Transaction_l.TABLECAPTION,
                  Store_p.FIELDCAPTION("Allowed Diff. in Trans."), Store_p."Allowed Diff. in Trans.");
                IF NOT CONFIRM(Txt, FALSE) THEN
                    ERROR(Text002);
            END;
        END;

        //Check for Counting Differences
        TotDiff := 0;
        TotCounted := 0;
        CountedAmtChecked := FALSE;
        StatementLine_l.RESET;
        StatementLine_l.SETRANGE("Statement No.", Stmt_p."No.");
        IF StatementLine_l.FINDSET THEN BEGIN
            REPEAT
                IF NOT RunningFromBatchPosting_p THEN
                    IF (StatementLine_l."Counted Amount in LCY" = 0) AND
                       (StatementLine_l."Trans. Amount in LCY" <> 0)
                    THEN
                        IF NOT CountedAmtChecked THEN BEGIN
                            exit(false);
                            CountedAmtChecked := TRUE;
                        END;
                TotCounted := TotCounted + StatementLine_l."Counted Amount in LCY";
                TotDiff := TotDiff + StatementLine_l."Counted Amount in LCY" - StatementLine_l."Trans. Amount in LCY";
            UNTIL StatementLine_l.NEXT = 0;

            OnBeforeCheckDifference(Stmt_p, Store_p, RunningFromBatchPosting_p, IsHandled);
            if not IsHandled then
                IF ABS(TotDiff) > 1.00 THEN BEGIN
                    IF NOT Store_p."Safe Mgnt. in Use" THEN
                        IF ABS(TotDiff) > Store_p."Max. Diff. to Allow Post." THEN
                            ERROR(
                            Text010 +
                            Text011, FORMAT(TotDiff),
                            Store_p."Max. Diff. to Allow Post.", Store_p.FIELDCAPTION("Max. Diff. to Allow Post."),
                            Store_p.TABLECAPTION);
                    Txt := STRSUBSTNO(
                    Text012 +
                    Text013, TotDiff);
                    IF NOT RunningFromBatchPosting_p THEN
                        Exit;
                END;
        END ELSE BEGIN
            TransactionStatus_l.SETCURRENTKEY("Statement No.");
            TransactionStatus_l.SETRANGE("Statement No.", Stmt_p."No.");
            IF TransactionStatus_l.ISEMPTY THEN
                ERROR(Text014);
        END;

        //Check Safe Lines
        SafeStatementLine_l.RESET;
        SafeStatementLine_l.SETRANGE("Statement No.", Stmt_p."No.");
        IF SafeStatementLine_l.FINDSET THEN BEGIN
            REPEAT
                IF SafeStatementLine_l.Amount <> 0 THEN BEGIN
                    SafeStatementLine_l.TESTFIELD("Tender Type");
                    SafeStatementLine_l.TESTFIELD("Bal. Account No.");
                END;
            UNTIL SafeStatementLine_l.NEXT = 0;
        END;

        //Check Shift
        IF NOT RunningFromBatchPosting_p THEN
            IF Stmt_p."Closing Method" = Stmt_p."Closing Method"::Shift THEN
                TestWorkShift(Stmt_p);

        exit(true);
    END;

    [Scope('OnPrem')]
    procedure PostPaymentToCustomer(DocNumber: Code[20]; SellToCustNo: Code[20]; TotalAmountPaid: Decimal; AppliesToDocNo: Code[20])
    var
        AppliesToDocType: Enum "Gen. Journal Document Type";
    begin
        GenJnlLine.Init;
        GenJnlLine."Posting Date" := Statement."Posting Date";
        GenJnlLine."Document Date" := Transaction.Date;
        GenJnlLine."Reason Code" := '';
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::Customer;
        GenJnlLine.Validate("Account No.", SellToCustNo);
        GenJnlLine.Description := Text043 + Transaction."Receipt No.";
        if TotalAmountPaid < 0 then
            GenJnlLine."Document Type" := GenJnlLine."Document Type"::Refund
        else
            GenJnlLine."Document Type" := GenJnlLine."Document Type"::Payment;
        GenJnlLine."Document No." := DocNumber;
        GenJnlLine."External Document No." := Statement."Posting No.";
        GenJnlLine."LSC Statement No." := Statement."Posting No.";
        GenJnlLine.Amount := -1 * TotalAmountPaid;
        GenJnlLine.Validate("Currency Code", Transaction."Trans. Currency");
        GenJnlLine.Amount := Round(GenJnlLine.Amount);
        GenJnlLine."Bill-to/Pay-to No." := SellToCustNo;
        GenJnlLine."Source Type" := GenJnlLine."Source Type"::Customer;
        GenJnlLine."Source No." := SellToCustNo;
        GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
        GenJnlLine."Salespers./Purch. Code" := '';
        GenJnlLine."LSC Sell-to Contact No." := Transaction."Sell-to Contact No.";

        if GenJnlLine.Amount < 0 then
            AppliesToDocType := GenJnlLine."Applies-to Doc. Type"::Invoice
        else
            AppliesToDocType := GenJnlLine."Applies-to Doc. Type"::"Credit Memo";

        if AppliesToDocNo = '' then begin
            OldCustLedgEntry.Reset;
            OldCustLedgEntry.SetCurrentKey("Document No.");
            OldCustLedgEntry.SetRange("Document Type", AppliesToDocType);
            OldCustLedgEntry.SetRange("Document No.", DocNumber);
            OldCustLedgEntry.SetRange("Customer No.", SellToCustNo);
            OldCustLedgEntry.SetRange(Open, true);
            OldCustLedgEntry.SetRange(Positive, GenJnlLine.Amount < 0);
            if OldCustLedgEntry.FindFirst then begin
                GenJnlLine."Applies-to Doc. Type" := AppliesToDocType;
                GenJnlLine."Applies-to Doc. No." := DocNumber;
            end
            else begin
                if Transaction."Customer Order ID" <> '' then begin
                    GenJnlLine."Applies-to Doc. Type" := GenJnlLine."Applies-to Doc. Type"::" ";
                    GenJnlLine."Applies-to Doc. No." := '';
                    GenJnlLine."Applies-to ID" := DocNumber;
                end;
            end;
        end else begin
            OldCustLedgEntry.Reset;
            OldCustLedgEntry.SetCurrentKey("Document No.");
            OldCustLedgEntry.SetRange("Document Type", GenJnlLine."Document Type"::Invoice);
            OldCustLedgEntry.SetRange("Document No.", AppliesToDocNo);
            OldCustLedgEntry.SetRange("Customer No.", SellToCustNo);
            OldCustLedgEntry.SetRange(Open, true);
            OldCustLedgEntry.SetRange(Positive, GenJnlLine.Amount < 0);
            if OldCustLedgEntry.FindFirst then begin
                GenJnlLine."Applies-to Doc. Type" := GenJnlLine."Document Type"::Invoice;
                GenJnlLine."Applies-to Doc. No." := AppliesToDocNo;
            end;
        end;

        CreateGenJnlLineDim(
          GenJnlLine,
          DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
          DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
          Database::"LSC Store", Store."No.",
          Database::Customer, SellToCustNo, 0, '', '');
        AddSourceCurrency(GenJnlLine);
        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
        GenJnlPostLine.RunWithCheck(GenJnlLine);
        TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
    end;

    [Scope('OnPrem')]
    procedure TotalPayment(): Decimal
    var
        TotalAmountPaid: Decimal;
        TotalDepositAmt: Decimal;
    begin
        TransPmtEntry.Reset;
        TransPmtEntry.SetRange("Store No.", Transaction."Store No.");
        TransPmtEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        TransPmtEntry.SetRange("Transaction No.", Transaction."Transaction No.");
        if TransPmtEntry.FindSet then
            repeat
                TenderType.Get(TransPmtEntry."Store No.", TransPmtEntry."Tender Type");
                if not (TenderType."Function" = TenderType."Function"::Customer) then
                    TotalAmountPaid := TotalAmountPaid + TransPmtEntry."Amount Tendered";
                if (TenderType."Function" = TenderType."Function"::Customer) and (TenderType."Auto Account Payment Tender") then
                    TotalDepositAmt := TotalDepositAmt + TransPmtEntry."Amount Tendered";
            until TransPmtEntry.Next = 0;
        TotalAmountPaid := TotalAmountPaid + TotalDepositAmt;
        exit(TotalAmountPaid);
    end;

    [Scope('OnPrem')]
    procedure PostDiscountBuffering(Len: Integer; AccountNo: Code[20]; DiscAmount: Decimal; DiscVATAmount: Decimal; SalesTypeCode: Code[20])
    var
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        EntryNo: Integer;
    begin
        TableID[3] := Database::"G/L Account";
        No[3] := AccountNo;

        GetDefaultDim(
            TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
            GlobalDimension2Code, Len);

        EntryNo := FindDimensions(TempDimBufNew);
        if EntryNo = 0 then
            EntryNo := InsertDimensions(TempDimBufNew);

        PostingBuffer[1]."Entry No." := EntryNo;
        PostingBuffer[1]."G/L Account" := AccountNo;
        PostingBuffer[1]."Department Code" := GlobalDimension1Code;
        PostingBuffer[1]."Project Code" := GlobalDimension2Code;
        PostingBuffer[1].Amount := DiscAmount;
        PostingBuffer[1]."VAT Base Amount" := DiscAmount;
        PostingBuffer[1]."VAT Amount" := DiscVATAmount;

        UpdPostingBuffer;
    end;

    [Scope('OnPrem')]
    procedure CreateDocNo(StoreNo: Code[10]; POSTerminalNo: Code[10]; TransactionNo: Integer) DocNo: Code[50]
    var
        LText001: Label 'The length of the Document No. (%1) can not exceed 20 characters.\The Document No. is constructed by concatenating the Store No. (%2), POS Terminal No. (%3) and the Transaction No. (%4) separated by "-".\Please make sure the combined length of the Store No. and the POS Terminal No. does not exceed 10 characters.';
    begin
        OnBeforeCreateDocNo(DocNo);
        DocNo := StoreNo + '-' +
          POSTerminalNo + '-' +
          Format(TransactionNo);
        OnAfterCreateDocNo(DocNo);
        if StrLen(DocNo) > 20 then
            Error(LText001, DocNo, StoreNo, POSTerminalNo, TransactionNo);
    end;

    [Scope('OnPrem')]
    procedure ExplodeDocNo(DocNo: Code[20]; StatementNo: Code[20]; var StoreNo: Code[10]; var PosNo: Code[10]; var TransNo: Integer)
    var
        PostedStatementLoc: Record "LSC Posted Statement";
        Position: Integer;
    begin
        PostedStatementLoc.Get(StatementNo);
        StoreNo := PostedStatementLoc."Store No.";
        DocNo := CopyStr(DocNo, StrLen(StoreNo) + 2);

        Position := StrPos(DocNo, '-');
        PosNo := CopyStr(DocNo, 1, Position);
        DocNo := CopyStr(DocNo, Position + 1);

        repeat
            Position := StrPos(DocNo, '-');
            if Position <> 0 then begin
                PosNo := PosNo + CopyStr(DocNo, 1, Position);
                DocNo := CopyStr(DocNo, Position + 1);
            end else
                Evaluate(TransNo, DocNo);
        until Position = 0;

        PosNo := CopyStr(PosNo, 1, StrLen(PosNo) - 1);
    end;

    [Scope('OnPrem')]
    procedure SetRunningFromBatchPosting()
    begin
        RunningFromBatchPosting := true;
    end;

    [Scope('OnPrem')]
    procedure SaveTempDimBufNew(FieldNumber: Integer; ShortcutDimCode: Code[20])
    begin
        GetGLSetup;
        TempDimBufNew.SetRange("Dimension Code", GLSetupShortcutDimCode[FieldNumber]);
        if ShortcutDimCode <> '' then begin
            if TempDimBufNew.FindFirst then begin
                TempDimBufNew.Validate("Dimension Value Code", ShortcutDimCode);
                TempDimBufNew.Modify;
            end else begin
                TempDimBufNew.Init;
                TempDimBufNew.Validate("Table ID", 0);
                TempDimBufNew.Validate("Entry No.", 0);
                TempDimBufNew.Validate("Dimension Code", GLSetupShortcutDimCode[FieldNumber]);
                TempDimBufNew.Validate("Dimension Value Code", ShortcutDimCode);
                TempDimBufNew.Insert;
            end;
        end else
            if TempDimBufNew.FindFirst then
                if TempDimBufNew."New Dimension Value Code" = '' then
                    TempDimBufNew.Delete
                else begin
                    TempDimBufNew."Dimension Value Code" := '';
                    TempDimBufNew.Modify;
                end;
        TempDimBufNew.Reset;
    end;

    [Scope('OnPrem')]
    procedure FindSalesType(pSalesType: Code[20])
    begin
        if pSalesType = '' then
            Clear(SalesTypes)
        else
            if pSalesType <> SalesTypes.Code then
                SalesTypes.Get(pSalesType);
    end;

    [Scope('OnPrem')]
    procedure BOMCalcStdCost(pItemNo: Code[20]; pDate: Date)
    var
        ItemLoc: Record Item;
        BOMComp: Record "BOM Component";
        TmpItem: Record Item temporary;
        CalculateStdCost: Codeunit "Calculate Standard Cost";
        ItemCostMgt: Codeunit ItemCostManagement;
    begin
        BOMComp.Reset;
        BOMComp.SetRange("Parent Item No.", pItemNo);
        if BOMComp.FindSet then
            repeat
                if (BOMComp.Type = BOMComp.Type::Item) and (BOMComp."No." <> '') then begin
                    ItemLoc.Get(BOMComp."No.");
                    ItemLoc.CalcFields("Assembly BOM");
                    if ItemLoc."Assembly BOM" then
                        BOMCalcStdCost(ItemLoc."No.", pDate);
                end;
            until BOMComp.Next = 0;

        ItemLoc.Get(pItemNo);
        if ItemLoc."Costing Method" = ItemLoc."Costing Method"::Standard then
            if not BOMItemBuffer2.Get('', '', pItemNo, '', pDate, false) then begin
                BOMItemBuffer2.Init;
                BOMItemBuffer2."Item No." := pItemNo;
                BOMItemBuffer2.Date := pDate;
                BOMItemBuffer2.Insert;

                TmpItem.Reset;
                TmpItem.DeleteAll;
                Clear(CalculateStdCost);
                CalculateStdCost.SetProperties(pDate, false, true, true, '', false);
                ItemLoc.SetRange("No.", ItemLoc."No.");
                CalculateStdCost.CalcItems(ItemLoc, TmpItem);
                if TmpItem.FindSet then
                    repeat
                        ItemCostMgt.UpdateStdCostShares(TmpItem);
                    until TmpItem.Next = 0;
                if ItemLoc."LSC Recipe Item Type" = ItemLoc."LSC Recipe Item Type"::Recipe then begin
                    BOMComp.Reset;
                    BOMComp.SetRange("Parent Item No.", ItemLoc."No.");
                    if BOMComp.FindFirst then
                        repeat
                            BOMComp.Validate("LSC Gross Weight");
                            BOMComp.Modify(true);
                        until BOMComp.Next = 0;
                end;
            end;
    end;

    [Scope('OnPrem')]
    procedure CreateServItemOnTransSalesEnt(TransactionHeader: Record "LSC Transaction Header"; TransSalesEntry: Record "LSC Trans. Sales Entry"; StatementNo: Code[20])
    var
        ServMgtSetup: Record "Service Mgt. Setup";
        ItemLoc: Record Item;
        GeneralLedgerSetup: Record "General Ledger Setup";
        ItemTrackingCode: Record "Item Tracking Code";
        ServItemGr: Record "Service Item Group";
        ServItem: Record "Service Item";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResSkillMgt: Codeunit "Resource Skill Mgt.";
        ServLogMgt: Codeunit ServLogManagement;
        x: Integer;
    begin
        ServMgtSetup.Get;
        GeneralLedgerSetup.Get;

        if not Store.Get(TransactionHeader."Store No.") then
            Store.Init;

        if TransSalesEntry.Quantity < 0 then begin
            ItemLoc.Get(TransSalesEntry."Item No.");
            if not ItemTrackingCode.Get(ItemLoc."Item Tracking Code") then
                ItemTrackingCode.Init;
            if (ServItemGr.Get(ItemLoc."Service Item Group")) and (ServItemGr."Create Service Item") then begin
                if TransSalesEntry.Quantity <> Round(TransSalesEntry.Quantity, 1) then
                    Error(
                      Text052,
                      ItemLoc.TableCaption,
                      ItemLoc."No.",
                      ServItemGr.TableCaption,
                      TransSalesEntry.FieldCaption(Quantity));

                for x := 1 to -TransSalesEntry.Quantity do begin
                    Clear(ServItem);
                    ServItem.Init;
                    ServMgtSetup.TestField("Service Item Nos.");
                    NoSeriesMgt.InitSeries(
                      ServMgtSetup."Service Item Nos.", ServItem."No. Series", 0D, ServItem."No.", ServItem."No. Series");
                    ServItem.Insert;
                    ServItem."Sales/Serv. Shpt. Document No." := StatementNo;
                    ServItem."Sales/Serv. Shpt. Line No." := 0;
                    ServItem.Validate(
                      Description,
                      CopyStr(ItemLoc.Description, 1, MaxStrLen(ServItem.Description)));
                    ServItem."Description 2" := CopyStr(
                      StrSubstNo('%1 %2', Statement.TableCaption, StatementNo),
                      1, MaxStrLen(ServItem."Description 2"));
                    ServItem.Validate("Customer No.", TransactionHeader."Customer No.");
                    ServItem.OmitAssignResSkills(true);
                    ServItem.Validate("Item No.", ItemLoc."No.");
                    ServItem.OmitAssignResSkills(false);
                    ServItem."Serial No." := TransSalesEntry."Serial No.";
                    ServItem."Variant Code" := TransSalesEntry."Variant Code";

                    ItemUnitOfMeasure.Get(ItemLoc."No.", TransSalesEntry."Unit of Measure");

                    ServItem.Validate("Sales Unit Cost", Round(ItemLoc."Unit Cost" /
                      ItemUnitOfMeasure."Qty. per Unit of Measure", GeneralLedgerSetup."Unit-Amount Rounding Precision"));
                    ServItem.Validate("Sales Unit Price", Round(TransSalesEntry."Net Price" /
                      ItemUnitOfMeasure."Qty. per Unit of Measure", GeneralLedgerSetup."Unit-Amount Rounding Precision"));
                    ServItem."Vendor No." := ItemLoc."Vendor No.";
                    ServItem."Vendor Item No." := ItemLoc."Vendor Item No.";
                    ServItem."Unit of Measure Code" := ItemLoc."Base Unit of Measure";
                    ServItem."Sales Date" := TransactionHeader.Date;
                    ServItem."Installation Date" := TransactionHeader.Date;
                    ServItem."Warranty % (Parts)" := ServMgtSetup."Warranty Disc. % (Parts)";
                    ServItem."Warranty % (Labor)" := ServMgtSetup."Warranty Disc. % (Labor)";
                    ServItem."Warranty Starting Date (Parts)" := TransactionHeader.Date;
                    if Format(ItemTrackingCode."Warranty Date Formula") <> '' then
                        ServItem."Warranty Ending Date (Parts)" :=
                          CalcDate(ItemTrackingCode."Warranty Date Formula", TransactionHeader.Date)
                    else
                        ServItem."Warranty Ending Date (Parts)" :=
                          CalcDate(
                            ServMgtSetup."Default Warranty Duration",
                            TransactionHeader.Date);
                    ServItem."Warranty Starting Date (Labor)" := TransactionHeader.Date;
                    ServItem."Warranty Ending Date (Labor)" :=
                      CalcDate(
                        ServMgtSetup."Default Warranty Duration",
                        TransactionHeader.Date);
                    ServItem.Modify;
                    ResSkillMgt.AssignServItemResSkills(ServItem);
                    Clear(ServLogMgt);
                    ServLogMgt.ServItemAutoCreated(ServItem);
                end;
            end;
        end;
    end;

    [Scope('OnPrem')]
    procedure CompressItemPostingBuffer()
    var
        ItemPostingBuffer_Temp: Record "LSC Item Posting Buffer";
        DiscBuffer_Temp: Record "LSC Discount Ledger Entry" temporary;
    begin
        if not ItemPostingBuffer[1]."Neg. Qty" then
            if ItemPostingBuffer[2].Get(ItemPostingBuffer[1].Type, ItemPostingBuffer[1]."Item No.", ItemPostingBuffer[1]."Location Code",
               ItemPostingBuffer[1]."Department Code", ItemPostingBuffer[1]."Document No.",
               ItemPostingBuffer[1]."Source No.",
               ItemPostingBuffer[1]."Serial No.", ItemPostingBuffer[1]."Lot No.",
               ItemPostingBuffer[1].Date, ItemPostingBuffer[1]."Salesperson Code",
               true, ItemPostingBuffer[1]."Currency Code",
               ItemPostingBuffer[1]."Offer No.",
               ItemPostingBuffer[1]."Promotion No.")
            then
                if ItemPostingBuffer[1].Quantity + ItemPostingBuffer[2].Quantity <> 0 then begin
                    SumItemPostingBuffer(1);
                    ItemPostingBuffer[2].Delete;
                    DiscLedgerMgt.SumDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.", ItemPostingBuffer[1]."Discount Entry No.");
                    DiscLedgerMgt.DeleteDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.");
                end else
                    if (ItemPostingBuffer[2]."Serial No." <> '') and (ItemPostingBuffer[2].Quantity <> 0) then begin
                        ItemPostingBuffer_Temp := ItemPostingBuffer[2];

                        ItemPostingBuffer_Temp.Quantity := -ItemPostingBuffer_Temp.Quantity / ItemPostingBuffer[2].Quantity;
                        ItemPostingBuffer_Temp.Amount := -ItemPostingBuffer_Temp.Amount / ItemPostingBuffer[2].Quantity;
                        ItemPostingBuffer_Temp."Cost Amount" := -ItemPostingBuffer_Temp."Cost Amount" / ItemPostingBuffer[2].Quantity;
                        ItemPostingBuffer_Temp."Line Discount Amount" := -ItemPostingBuffer_Temp."Line Discount Amount" /
                          ItemPostingBuffer[2].Quantity;
                        ItemPostingBuffer_Temp."Inv. Discount Amount" := -ItemPostingBuffer_Temp."Inv. Discount Amount" /
                          ItemPostingBuffer[2].Quantity;
                        DiscLedgerMgt.GetDiscBufferFragtion(ItemPostingBuffer_Temp."Discount Entry No.", -ItemPostingBuffer[2].Quantity,
                          DiscBuffer_Temp);
                        DiscLedgerMgt.SaveCurrDiscBuffer(DiscBuffer_Temp);

                        ItemPostingBuffer[2].Quantity := ItemPostingBuffer[2].Quantity -
                          ItemPostingBuffer_Temp.Quantity;
                        ItemPostingBuffer[2].Amount := ItemPostingBuffer[2].Amount -
                          ItemPostingBuffer_Temp.Amount;
                        ItemPostingBuffer[2]."Cost Amount" := ItemPostingBuffer[2]."Cost Amount" -
                          ItemPostingBuffer_Temp."Cost Amount";
                        ItemPostingBuffer[2]."Line Discount Amount" := ItemPostingBuffer[2]."Line Discount Amount" -
                          ItemPostingBuffer_Temp."Line Discount Amount";
                        ItemPostingBuffer[2]."Inv. Discount Amount" := ItemPostingBuffer[2]."Inv. Discount Amount" -
                          ItemPostingBuffer_Temp."Inv. Discount Amount";
                        ItemPostingBuffer[2].Modify;
                        DiscLedgerMgt.RevertSignCurrDiscBuffer;
                        DiscLedgerMgt.GetCurrDiscBuffer(DiscBuffer_Temp);
                        DiscLedgerMgt.UpdateDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.", DiscBuffer_Temp);
                        SumItemPostingBuffer(1);
                        DiscLedgerMgt.SumDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.", ItemPostingBuffer[1]."Discount Entry No.");
                        DiscLedgerMgt.DeleteDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.");

                        ItemPostingBuffer[2] := ItemPostingBuffer_Temp;
                        ItemPostingBuffer[2].Modify;
                        DiscLedgerMgt.RevertSignCurrDiscBuffer;
                        DiscLedgerMgt.GetCurrDiscBuffer(DiscBuffer_Temp);
                        DiscLedgerMgt.UpdateDiscBuffer(ItemPostingBuffer[2]."Discount Entry No.", DiscBuffer_Temp);
                    end;
    end;

    [Scope('OnPrem')]
    procedure NextEntryShouldBePositive(var pItemPostingBuffer: Record "LSC Item Posting Buffer"): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.Reset;
        ItemLedgerEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive,
          "Location Code", "Posting Date", "Expiration Date", "Lot No.", "Serial No.");
        ItemLedgerEntry.SetRange("Item No.", pItemPostingBuffer."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", pItemPostingBuffer."Source No.");
        ItemLedgerEntry.SetRange("Location Code", pItemPostingBuffer."Location Code");
        ItemLedgerEntry.SetRange("Serial No.", pItemPostingBuffer."Serial No.");
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange(Positive, true);

        if ItemLedgerEntry.FindFirst then
            exit(false)
        else
            exit(true);
    end;

    [Scope('OnPrem')]
    procedure LotInventoryAvailable(var pItemPostingBuffer: Record "LSC Item Posting Buffer"): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.Reset;
        ItemLedgerEntry.SetCurrentKey("Item No.", Open, "Variant Code", Positive,
          "Location Code", "Posting Date", "Expiration Date", "Lot No.", "Serial No.");
        ItemLedgerEntry.SetRange("Item No.", pItemPostingBuffer."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", pItemPostingBuffer."Source No.");
        ItemLedgerEntry.SetRange("Location Code", pItemPostingBuffer."Location Code");
        ItemLedgerEntry.SetRange("Lot No.", pItemPostingBuffer."Lot No.");
        ItemLedgerEntry.CalcSums(Quantity);

        if ItemLedgerEntry.Quantity < pItemPostingBuffer.Quantity then
            exit(false)
        else
            exit(true);
    end;

    [Scope('OnPrem')]
    procedure OkToPostDirect(var pItemPostingBuffer: Record "LSC Item Posting Buffer"): Boolean
    var
        PostDirect: Boolean;
    begin
        if pItemPostingBuffer."Serial No." <> '' then
            if pItemPostingBuffer."Neg. Qty" then
                if NextEntryShouldBePositive(pItemPostingBuffer) then
                    PostDirect := true
                else
                    PostDirect := false
            else
                if NextEntryShouldBePositive(pItemPostingBuffer) then
                    PostDirect := false
                else
                    PostDirect := true
        else
            if pItemPostingBuffer."Neg. Qty" then
                PostDirect := true
            else
                if LotInventoryAvailable(pItemPostingBuffer) then
                    PostDirect := true
                else
                    PostDirect := false;

        exit(PostDirect);
    end;

    [Scope('OnPrem')]
    procedure FindReversePosting(var pItemPostingBuffer_In: Record "LSC Item Posting Buffer"; var pItemPostingBuffer_Out: Record "LSC Item Posting Buffer"): Boolean
    begin
        ItemPostingBuffer[2].Reset;
        ItemPostingBuffer[2].SetRange(Type, pItemPostingBuffer_In.Type);
        ItemPostingBuffer[2].SetRange("Item No.", pItemPostingBuffer_In."Item No.");
        ItemPostingBuffer[2].SetFilter("Source No.", '%1', pItemPostingBuffer_In."Source No.");
        ItemPostingBuffer[2].SetRange("Location Code", pItemPostingBuffer_In."Location Code");
        ItemPostingBuffer[2].SetRange("Serial No.", pItemPostingBuffer_In."Serial No.");
        ItemPostingBuffer[2].SetRange("Neg. Qty", not pItemPostingBuffer_In."Neg. Qty");
        if ItemPostingBuffer[2].FindFirst then begin
            pItemPostingBuffer_Out := ItemPostingBuffer[2];
            ItemPostingBuffer[2].Delete;
            exit(true);
        end else begin
            Clear(pItemPostingBuffer_Out);
            exit(false);
        end;
    end;

    [Scope('OnPrem')]
    procedure PostDepositPayments(CustomerNo: Code[20])
    var
        TransPmtEntryLoc: Record "LSC Trans. Payment Entry";
        TenderTypeLoc: Record "LSC Tender Type";
    begin
        TenderTypeLoc.SetRange("Store No.", Transaction."Store No.");
        TenderTypeLoc.SetRange("Auto Account Payment Tender", true);
        TenderTypeLoc.SetRange("Function", TenderTypeLoc."Function"::Customer);
        if not TenderTypeLoc.FindFirst then
            Error(Text053, Transaction."Store No.");

        TransPmtEntryLoc.SetRange("Store No.", Transaction."Store No.");
        TransPmtEntryLoc.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        TransPmtEntryLoc.SetRange("Transaction No.", Transaction."Transaction No.");
        TransPmtEntryLoc.SetRange("Tender Type", TenderTypeLoc.Code);
        if TransPmtEntryLoc.FindSet then
            repeat
                PostPaymentToCustomer(Transaction."Customer Order ID", CustomerNo, -TransPmtEntryLoc."Amount Tendered",
                                      FindSalesOrderPrepaymentInv(Transaction."Customer Order ID"));
            until TransPmtEntryLoc.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure FindSalesOrderPrepaymentInv(DocumentNo: Code[20]): Code[20]
    var
        SalesInvHeader: Record "Sales Invoice Header";
    begin
        SalesInvHeader.SetCurrentKey("Prepayment Order No.", "Prepayment Invoice");
        SalesInvHeader.SetRange("Prepayment Order No.", DocumentNo);
        SalesInvHeader.SetRange("Prepayment Invoice", true);
        if SalesInvHeader.FindFirst then
            exit(SalesInvHeader."No.");
    end;

    [Scope('OnPrem')]
    procedure CreateDiscBuffer(var pTransSalesEntry: Record "LSC Trans. Sales Entry"; pVATFactor: Decimal)
    var
        TransDiscountEntry: Record "LSC Trans. Discount Entry";
        DiscBuffer: Record "LSC Discount Ledger Entry" temporary;
    begin
        TransDiscountEntry.Reset;
        TransDiscountEntry.SetRange("Store No.", pTransSalesEntry."Store No.");
        TransDiscountEntry.SetRange("POS Terminal No.", pTransSalesEntry."POS Terminal No.");
        TransDiscountEntry.SetRange("Transaction No.", pTransSalesEntry."Transaction No.");
        TransDiscountEntry.SetRange("Line No.", pTransSalesEntry."Line No.");
        if TransDiscountEntry.FindSet then
            repeat
                DiscBuffer.Init;
                DiscBuffer."Offer Type" := TransDiscountEntry."Offer Type";
                DiscBuffer."Offer No." := TransDiscountEntry."Offer No.";
                if glUndoItemPosting then
                    DiscBuffer.Quantity := TransSalesEntry.Quantity
                else
                    DiscBuffer.Quantity := -TransSalesEntry.Quantity;
                DiscBuffer."Sales Amount" := -TransSalesEntry."Net Amount";
                DiscBuffer."Discount Amount" := Round(TransDiscountEntry."Discount Amount" / pVATFactor);
                DiscBuffer.Insert;
            until TransDiscountEntry.Next = 0;
        DiscLedgerMgt.SaveCurrDiscBuffer(DiscBuffer);
    end;

    [Scope('OnPrem')]
    procedure InsertSalesLineDiscEntry(var pTransSalesEntry: Record "LSC Trans. Sales Entry"; var pSalesLine: Record "Sales Line")
    var
        TransDiscountEntry: Record "LSC Trans. Discount Entry";
        SalesLineDiscEntry: Record "LSC Sales Line Discount Entry";
    begin
        TransDiscountEntry.Reset;
        TransDiscountEntry.SetRange("Store No.", pTransSalesEntry."Store No.");
        TransDiscountEntry.SetRange("POS Terminal No.", pTransSalesEntry."POS Terminal No.");
        TransDiscountEntry.SetRange("Transaction No.", pTransSalesEntry."Transaction No.");
        TransDiscountEntry.SetRange("Line No.", pTransSalesEntry."Line No.");
        if TransDiscountEntry.FindSet then
            repeat
                InitSalesLineDiscEntry(pSalesLine, SalesLineDiscEntry);
                SalesLineDiscEntry."Offer Type" := TransDiscountEntry."Offer Type";
                SalesLineDiscEntry."Offer No." := TransDiscountEntry."Offer No.";
                SalesLineDiscEntry."Discount Amount" := TransDiscountEntry."Discount Amount";
                SalesLineDiscEntry.Insert;
            until TransDiscountEntry.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure InitSalesLineDiscEntry(var pSalesLine: Record "Sales Line"; var pSalesLineDiscEntry: Record "LSC Sales Line Discount Entry")
    begin
        pSalesLineDiscEntry.Init;
        pSalesLineDiscEntry."Document Type" := pSalesLine."Document Type";
        pSalesLineDiscEntry."Document No." := pSalesLine."Document No.";
        pSalesLineDiscEntry."Document Line No." := pSalesLine."Line No.";
    end;

    [Scope('OnPrem')]
    procedure GetTransLineDiscAmount(var pTransSalesEntry: Record "LSC Trans. Sales Entry"; pOfferType: Option Promotion,Deal,Multibuy,"Mix&Match","Disc. Offer","Total Discount","Tender Type","Item Point","Line Discount",Customer,Infocode,"Member Point",Coupon,Total,Line): Decimal
    var
        TransDiscountEntry: Record "LSC Trans. Discount Entry";
    begin
        TransDiscountEntry.Reset;
        TransDiscountEntry.SetRange("Store No.", pTransSalesEntry."Store No.");
        TransDiscountEntry.SetRange("POS Terminal No.", pTransSalesEntry."POS Terminal No.");
        TransDiscountEntry.SetRange("Transaction No.", pTransSalesEntry."Transaction No.");
        TransDiscountEntry.SetRange("Line No.", pTransSalesEntry."Line No.");
        TransDiscountEntry.SetRange("Offer Type", pOfferType);
        TransDiscountEntry.CalcSums("Discount Amount");
        exit(TransDiscountEntry."Discount Amount");
    end;

    [Scope('OnPrem')]
    procedure TestDeleteHeader(pStatement: Record "LSC Statement"; var pPostedStatement: Record "LSC Posted Statement")
    begin
        with pStatement do begin
            Clear(pPostedStatement);
            SourceCodeSetup.Get;
            SourceCodeSetup.TestField("Deleted Document");
            SourceCode.Get(SourceCodeSetup."Deleted Document");
            if ("Posting No. Series" <> '') and
              (("Posting No." <> '') or ("No. Series" = "Posting No. Series"))
            then begin
                pPostedStatement.TransferFields(pStatement);
                if "Posting No." <> '' then
                    pPostedStatement."No." := "Posting No.";
                pPostedStatement."Pre-Assigned No. Series" := "No. Series";
                pPostedStatement."No. Series" := "Posting No. Series";
                pPostedStatement."Pre-Assigned No." := "No.";
            end;
        end;
    end;

    [Scope('OnPrem')]
    procedure DeleteStatementHeader(pStatement: Record "LSC Statement"; var pPostedStatement: Record "LSC Posted Statement")
    var
        lPostedStatemLine: Record "LSC Posted Statement Line";
    begin
        TestDeleteHeader(pStatement, pPostedStatement);
        if pPostedStatement."No." <> '' then begin
            pPostedStatement.Insert;
            lPostedStatemLine.Init;
            lPostedStatemLine."Statement No." := pPostedStatement."No.";
            lPostedStatemLine."Line No." := 10000;
            lPostedStatemLine."Tender Type Name" := CopyStr(SourceCode.Description, 1, MaxStrLen(lPostedStatemLine."Tender Type Name"));
            lPostedStatemLine.Insert;
        end;
    end;

    [Scope('OnPrem')]
    procedure UpdatePaymentBuffer(pAccountType: Integer; pAccountNo: Code[20]; pDescription: Text[50]; pCurrencyCode: Code[20]; pAmount: Decimal; pAmountLCY: Decimal)
    var
        IsHandled: Boolean;
    begin
        OnBeforeUpdatePaymentBuffer(IsHandled);
        if IsHandled then
            exit;

        PaymPostingBuffer.Reset;
        if pAccountType = 0 then
            PaymPostingBuffer.SetRange(Type, PaymPostingBuffer.Type::"G/L Account")
        else
            PaymPostingBuffer.SetRange(Type, PaymPostingBuffer.Type::"Bank Account");
        PaymPostingBuffer.SetRange("G/L Account", pAccountNo);
        PaymPostingBuffer.SetFilter("Currency Code", pCurrencyCode);

        if not PaymPostingBuffer.FindFirst then begin
            BufferLineNo += 1;
            PaymPostingBuffer.Init;
            if pAccountType = 0 then
                PaymPostingBuffer.Type := PaymPostingBuffer.Type::"G/L Account"
            else
                PaymPostingBuffer.Type := PaymPostingBuffer.Type::"Bank Account";
            PaymPostingBuffer."G/L Account" := pAccountNo;
            PaymPostingBuffer."Currency Code" := pCurrencyCode;
            PaymPostingBuffer."Entry No." := BufferLineNo;
            PaymPostingBuffer."Payment Posting Description" := pDescription;
            PaymPostingBuffer.Insert;
        end;

        PaymPostingBuffer."POS Line Disc. Amount" += pAmountLCY;
        PaymPostingBuffer.Amount += pAmount;
        PaymPostingBuffer.Modify;
    end;

    [Scope('OnPrem')]
    procedure PostPaymentBuffer()
    var
        lCurrencyGainLoss: Decimal;
    begin
        PaymPostingBuffer.Reset;
        if PaymPostingBuffer.FindSet then
            repeat
                lCurrencyGainLoss := 0;
                Clear(GenJnlLine);
                GenJnlLine.Init;
                if PaymPostingBuffer.Type = PaymPostingBuffer.Type::"G/L Account" then
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account"
                else
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"Bank Account";
                GenJnlLine."Posting Date" := Statement."Posting Date";
                GenJnlLine."Document Date" := Statement."Posting Date";
                GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                GenJnlLine."Document No." := Statement."Posting No.";
                GenJnlLine.Validate("Account No.", PaymPostingBuffer."G/L Account");
                GenJnlLine.Description := PaymPostingBuffer."Payment Posting Description";
                GenJnlLine."System-Created Entry" := true;
                GenJnlLine.Amount := PaymPostingBuffer.Amount;
                if PaymPostingBuffer."Currency Code" <> '' then begin
                    GenJnlLine.Validate("Currency Code", PaymPostingBuffer."Currency Code");
                    lCurrencyGainLoss := GenJnlLine."Amount (LCY)" - PaymPostingBuffer."POS Line Disc. Amount";
                end
                else
                    GenJnlLine.Validate("Currency Code", Store."Currency Code");
                GenJnlLine."VAT Amount" := 0;
                GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                CreateGenJnlLineDim(
                  GenJnlLine,
                  DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                  DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                  Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                if GenJnlLine."Amount (LCY)" <> 0 then begin
                    AddSourceCurrency(GenJnlLine);
                    OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                    GenJnlPostLine.RunWithCheck(GenJnlLine);
                end;
                TotalSum := TotalSum + GenJnlLine."Amount (LCY)";

                if lCurrencyGainLoss <> 0 then begin
                    Currency.Get(PaymPostingBuffer."Currency Code");
                    if lCurrencyGainLoss > 0 then
                        GLAccount.Get(Currency."Realized Gains Acc.")
                    else
                        GLAccount.Get(Currency."Realized Losses Acc.");
                    Clear(GenJnlLine);
                    GenJnlLine.Init;
                    GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
                    GenJnlLine."Posting Date" := Statement."Posting Date";
                    GenJnlLine."Document Date" := Statement."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."External Document No." := Statement."Posting No.";
                    GenJnlLine."Document No." := Statement."Posting No.";
                    GenJnlLine.Validate("Account No.", GLAccount."No.");
                    GenJnlLine.Description := CopyStr(StrSubstNo(Text054, PaymPostingBuffer."Payment Posting Description", PaymPostingBuffer."Currency Code"), 1, 50);
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Validate(Amount, -lCurrencyGainLoss);

                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";
                    CreateGenJnlLineDim(
                      GenJnlLine,
                      DimManagement.TypeToTableID1(GenJnlLine."Account Type".AsInteger()), GenJnlLine."Account No.",
                      DimManagement.TypeToTableID1(GenJnlLine."Bal. Account Type".AsInteger()), GenJnlLine."Bal. Account No.",
                      Database::"LSC Store", Store."No.", 0, '', 0, '', '');
                    if GenJnlLine."Amount (LCY)" <> 0 then begin
                        AddSourceCurrency(GenJnlLine);
                        OnBeforeGenJnlLineRunWithCheckInStatementPost(GenJnlLine);
                        GenJnlPostLine.RunWithCheck(GenJnlLine);
                    end;
                    TotalSum := TotalSum + GenJnlLine."Amount (LCY)";
                end;
            until PaymPostingBuffer.Next = 0;
        PaymPostingBuffer.DeleteAll;
    end;

    [Scope('OnPrem')]
    procedure CheckTransSubTables(Transaction_p: Record "LSC Transaction Header") Result: Boolean
    var
        TransSalesEntry_l: Record "LSC Trans. Sales Entry";
        TransPaymEntry_l: Record "LSC Trans. Payment Entry";
        n: Integer;
    begin
        Result := true;
        if Transaction_p."No. of Item Lines" <> 0 then begin
            TransSalesEntry_l.SetRange("Store No.", Transaction_p."Store No.");
            TransSalesEntry_l.SetRange("POS Terminal No.", Transaction_p."POS Terminal No.");
            TransSalesEntry_l.SetRange("Transaction No.", Transaction_p."Transaction No.");
            Result := Result and (Transaction_p."No. of Item Lines" - TransSalesEntry_l.Count = 0);
        end;
        if Transaction_p."No. of Payment Lines" <> 0 then begin
            TransPaymEntry_l.SetRange("Store No.", Transaction_p."Store No.");
            TransPaymEntry_l.SetRange("POS Terminal No.", Transaction_p."POS Terminal No.");
            TransPaymEntry_l.SetRange("Transaction No.", Transaction_p."Transaction No.");
            Result := Result and (Transaction_p."No. of Payment Lines" - TransPaymEntry_l.Count = 0);
        end;
    end;

    local procedure SetTransInvAdjmtEntryStatus(var TransactionStatus: Record "LSC Transaction Status")
    var
        TransInvAdjmtEntry: Record "LSC Trans. Inv. Adjmt. Entry";
        TransInvAdjmtEntrySt: Record "LSC Trans. Inv Adjmt. Entry St";
    begin
        TransInvAdjmtEntry.Reset;
        TransInvAdjmtEntry.SetRange("Store No.", TransactionStatus."Store No.");
        TransInvAdjmtEntry.SetRange("POS Terminal No.", TransactionStatus."POS Terminal No.");
        TransInvAdjmtEntry.SetRange("Transaction No.", TransactionStatus."Transaction No.");
        if TransInvAdjmtEntry.FindSet then
            repeat
                if not TransInvAdjmtEntrySt.Get(TransInvAdjmtEntry."Store No.", TransInvAdjmtEntry."POS Terminal No.", TransInvAdjmtEntry."Transaction No.",
                  TransInvAdjmtEntry."Line No.", TransInvAdjmtEntry."Location Code")
                then begin
                    TransInvAdjmtEntrySt.Init;
                    TransInvAdjmtEntrySt.TransferFields(TransInvAdjmtEntry, true);
                    TransInvAdjmtEntrySt.Status := TransactionStatus.Status;
                    TransInvAdjmtEntrySt.Insert(true);
                end else begin
                    TransInvAdjmtEntrySt.Status := TransactionStatus.Status;
                    TransInvAdjmtEntrySt.Modify(true);
                end;
            until TransInvAdjmtEntry.Next = 0;
    end;

    local procedure ProcessItemAdjustPostBuffer(var PostingException_p: Record "LSC Posting Exception")
    begin
        ItemAdjustPostBuffer[1] := ItemPostingBuffer[1];
        ItemAdjustPostBuffer[1].Type := ItemAdjustPostBuffer[1].Type::ExPositiveAdjust;
        ItemAdjustPostBuffer[1]."Salesperson Code" := '';
        ItemAdjustPostBuffer[1]."Offer No." := '';
        ItemAdjustPostBuffer[1]."Promotion No." := '';
        UpdItemAdjustPostBuffer;

        ItemAdjustPostBuffer[1].Type := ItemAdjustPostBuffer[1].Type::ExNegativeAdjust;
        ItemAdjustPostBuffer[1]."Location Code" := PostingException_p."Sourcing Location Code";
        UpdItemAdjustPostBuffer;
    end;

    local procedure UpdItemAdjustPostBuffer()
    begin
        ItemAdjustPostBuffer[2] := ItemAdjustPostBuffer[1];
        if ItemAdjustPostBuffer[2].Find then begin
            ItemAdjustPostBuffer[2].Quantity := ItemAdjustPostBuffer[2].Quantity + ItemAdjustPostBuffer[1].Quantity;
            ItemAdjustPostBuffer[2].Modify;
        end else begin
            if ItemAdjustPostBuffer[1].Type = ItemAdjustPostBuffer[1].Type::ExPositiveAdjust then
                ItemAdjustPostBuffer[1]."Adjustment Link No." := PostingExceptionUtility.GetNextEntryNo;
            ItemAdjustPostBuffer[1].Insert;
        end;
    end;

    local procedure PostItemAdjustment()
    var
        i: Integer;
    begin
        OnBeforePostItemAdjustment(ItemAdjustPostBuffer[1], Statement);
        Item.Get(ItemAdjustPostBuffer[1]."Item No.");
        TransPostingFunctions.SetItemBlockReserve(Item."No.");

        Clear(ItemJnlLine);
        ItemJnlLine.Init;
        ItemJnlLine."Item No." := ItemAdjustPostBuffer[1]."Item No.";
        ItemJnlLine."Variant Code" := ItemAdjustPostBuffer[1]."Source No.";
        ItemJnlLine."Posting Date" := ItemAdjustPostBuffer[1].Date;
        ItemJnlLine."Document Date" := Statement."Posting Date";
        if ItemAdjustPostBuffer[1].Type = ItemAdjustPostBuffer[1].Type::ExNegativeAdjust then
            ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::"Negative Adjmt.")
        else
            ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::"Positive Adjmt.");
        ItemJnlLine."Document No." := ItemAdjustPostBuffer[1]."Document No.";
        ItemJnlLine.Description := Item.Description;
        ItemJnlLine."Location Code" := ItemAdjustPostBuffer[1]."Location Code";
        ItemJnlLine."Inventory Posting Group" := Item."Inventory Posting Group";
        ItemJnlLine."Source Posting Group" := '';
        if Item."Base Unit of Measure" <> '' then begin
            ItemJnlLine.Validate("Unit of Measure Code", Item."Base Unit of Measure");
            ItemJnlLine.Validate(Quantity, ItemAdjustPostBuffer[1].Quantity);
        end else begin
            ItemJnlLine."Unit of Measure Code" := '';
            ItemJnlLine."Qty. per Unit of Measure" := 1;
            ItemJnlLine.Validate("Quantity (Base)", ItemAdjustPostBuffer[1].Quantity);
        end;
        ItemJnlLine."Source Code" := BackOfficeSetup."Source Code";
        ItemJnlLine."Gen. Bus. Posting Group" := ItemAdjustPostBuffer[1]."Gen. Bus. Posting Group";
        ItemJnlLine."Gen. Prod. Posting Group" := ItemAdjustPostBuffer[1]."Gen. Prod. Posting Group";

        ItemJnlLine."Expiration Date" := ItemPostingBuffer[1]."Expiration Date";
        if (ItemPostingBuffer[1]."Serial No." <> '') or (ItemPostingBuffer[1]."Lot No." <> '') then
            TransPostingFunctions.AddSerialNoAndLotNoTracking(ItemJnlLine, ItemPostingBuffer[1]."Serial No.", ItemPostingBuffer[1]."Lot No.", ItemPostingBuffer[1]."Expiration Date");

        i := 1;
        Clear(TableID);
        Clear(No);
        TableID[i] := Database::Item;
        No[i] := ItemJnlLine."Item No.";
        i += 1;
        TableID[i] := Database::"LSC Store";
        No[i] := Store."No.";
        CreateItemJnlLineDim(ItemJnlLine, TableID, No, '');

        OnBeforeItemJnlLinePostLine(ItemJnlLine, Statement, ItemPostingBuffer[1]);
        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
        OnAfterItemJnlLinePostLine(ItemJnlLine, Statement);
        ItemAdjustPostBuffer[1]."Item Ledger Entry No." := ItemJnlLine."Item Shpt. Entry No.";
        ItemAdjustPostBuffer[1].Modify;

        TransPostingFunctions.ResetItemBlockReserve;
    end;

    [Scope('OnPrem')]
    procedure CheckSerialNo(StoreNoIn: Code[10]; StatementNoIn: Code[20]; var ExplanationMsgOut: Text) ExplanationMsgFound: Boolean
    var
        Statement_L: Record "LSC Statement";
        TransactionStatus_L: Record "LSC Transaction Status";
        TransSalesEntry_L: Record "LSC Trans. Sales Entry";
        TransSalesEntry_TEMP: Record "LSC Trans. Sales Entry" temporary;
        Item_L: Record Item;
        ItemTrackingCode_L: Record "Item Tracking Code";
        TransSalesLineAlreadyPosted: Boolean;
    begin
        ExplanationMsgFound := false;
        ExplanationMsgOut := '';
        if not Statement_L.Get(StoreNoIn, StatementNoIn) then
            exit;
        Statement_L.CalcFields("Serial/Lot No. Not Valid");
        if Statement_L."Serial/Lot No. Not Valid" = 0 then
            exit;

        TransSalesEntry_TEMP.Reset;
        TransSalesEntry_TEMP.DeleteAll;
        TransSalesEntry_L.Reset;
        TransactionStatus_L.Reset;
        TransactionStatus_L.SetCurrentKey("Statement No.");
        TransactionStatus_L.SetRange("Statement No.", StatementNoIn);
        TransactionStatus_L.SetRange("Store No.", StoreNoIn);
        TransactionStatus_L.SetFilter("Serial/Lot No. Not Valid", '<>0');
        if TransactionStatus_L.FindSet then
            repeat
                TransSalesEntry_L.SetRange("Store No.", TransactionStatus_L."Store No.");
                TransSalesEntry_L.SetRange("POS Terminal No.", TransactionStatus_L."POS Terminal No.");
                TransSalesEntry_L.SetRange("Transaction No.", TransactionStatus_L."Transaction No.");
                TransSalesEntry_L.SetRange("Serial/Lot No. Not Valid", true);
                if TransSalesEntry_L.FindSet then
                    repeat
                        if Item_L.Get(TransSalesEntry_L."Item No.") then
                            if ItemTrackingCode_L.Get(Item_L."Item Tracking Code") then
                                if (ItemTrackingCode_L."SN Specific Tracking") or
                                  (ItemTrackingCode_L."SN Info. Outbound Must Exist") or
                                  (ItemTrackingCode_L."SN Sales Outbound Tracking") then begin
                                    TransSalesEntry_TEMP.Reset;
                                    TransSalesEntry_TEMP.SetRange("Item No.", TransSalesEntry_L."Item No.");
                                    TransSalesEntry_TEMP.SetFilter("Variant Code", '%1', TransSalesEntry_L."Variant Code");
                                    TransSalesEntry_TEMP.SetRange("Serial No.", TransSalesEntry_L."Serial No.");
                                    if TransSalesEntry_TEMP.FindFirst then begin
                                        TransSalesEntry_TEMP.Quantity := TransSalesEntry_TEMP.Quantity + TransSalesEntry_L.Quantity;
                                        TransSalesEntry_TEMP.Modify;
                                    end
                                    else begin
                                        TransSalesEntry_TEMP := TransSalesEntry_L;
                                        TransSalesEntry_TEMP.Insert;
                                    end;
                                end;
                    until TransSalesEntry_L.Next = 0;
            until TransactionStatus_L.Next = 0;

        TransSalesEntry_TEMP.Reset;
        TransSalesEntry_TEMP.SetFilter(Quantity, '0');
        TransSalesEntry_TEMP.DeleteAll;
        TransSalesEntry_TEMP.SetRange(Quantity);

        if TransSalesEntry_TEMP.FindSet then
            repeat
                TransSalesEntry_L.Reset;
                TransSalesEntry_L.SetCurrentKey("Item No.", "Variant Code", Date, "Store No.", "Serial No.", "Lot No.");
                TransSalesEntry_L.SetRange("Item No.", TransSalesEntry_TEMP."Item No.");
                TransSalesEntry_L.SetFilter("Variant Code", '%1', TransSalesEntry_TEMP."Variant Code");
                TransSalesEntry_L.SetRange("Store No.", TransSalesEntry_TEMP."Store No.");
                TransSalesEntry_L.SetRange("Serial No.", TransSalesEntry_TEMP."Serial No.");
                if TransSalesEntry_L.FindSet then
                    repeat
                        TransSalesLineAlreadyPosted := false;
                        if TransactionStatus_L.Get(TransSalesEntry_L."Store No.", TransSalesEntry_L."POS Terminal No.", TransSalesEntry_L."Transaction No.") then
                            if (TransactionStatus_L.Status in [TransactionStatus_L.Status::"Items Posted", TransactionStatus_L.Status::Posted]) and
                              (TransactionStatus_L."Statement No." <> StatementNoIn) then
                                TransSalesLineAlreadyPosted := true;
                        if not TransSalesLineAlreadyPosted then
                            if ((TransSalesEntry_TEMP.Quantity > 0) and (TransSalesEntry_L.Quantity < 0)) or
                              ((TransSalesEntry_TEMP.Quantity < 0) and (TransSalesEntry_L.Quantity > 0)) then begin
                                ExplanationMsgFound := true;
                                if ExplanationMsgOut = '' then
                                    ExplanationMsgOut := StrSubstNo(ExplanationMsg, TransSalesEntry_TEMP."Item No.", TransSalesEntry_TEMP."Serial No.",
                                      TransSalesEntry_TEMP."Receipt No.", TransSalesEntry_L."Receipt No.")
                                else
                                    ExplanationMsgOut := '\' + StrSubstNo(ExplanationMsg, TransSalesEntry_TEMP."Item No.", TransSalesEntry_TEMP."Serial No.",
                                      TransSalesEntry_TEMP."Receipt No.", TransSalesEntry_L."Receipt No.");
                            end;
                    until TransSalesEntry_L.Next = 0;
            until TransSalesEntry_TEMP.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure PostTax(DocNumber: Code[10])
    var
        TaxArea: Record "Tax Area";
        TaxJurisdiction: Record "Tax Jurisdiction";
        CurrExchRate: Record "Currency Exchange Rate";
        TempSalesLineForSalesTax: Record "Sales Line" temporary;
        SalesTaxCalculate: Codeunit "Sales Tax Calculate";
        UseDate: Date;
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        RemSalesTaxAmt: Decimal;
        RemSalesTaxSrcAmt: Decimal;
        EntryNo: Integer;
        Len: Integer;
        SalesTaxCountry: Option US,CA,,,,,,,,,,,,NoTax;
    begin
        UseDate := Statement."Posting Date";
        LineCounter := 0;
        if not Statement.Debugmode then
            Win.Update(10, Text10000);

        if TaxGenJnlPostingBuffer.FindSet() then
            repeat
                LineCounter := LineCounter + 1;
                if not Statement.Debugmode then
                    Win.Update(5, LineCounter);
                tmpGenJnlLine.Get('', '', TaxGenJnlPostingBuffer.Int);
                TempDimSetEntry.DeleteAll;
                TempDimBufNew.DeleteAll;
                if GetDimensions(TaxGenJnlPostingBuffer."Entry No.", TempDimBufNew) then begin
                    if TempDimBufNew.FindSet then
                        repeat
                            DimVal.Get(TempDimBufNew."Dimension Code", TempDimBufNew."Dimension Value Code");
                            TempDimSetEntry."Dimension Code" := TempDimBufNew."Dimension Code";
                            TempDimSetEntry."Dimension Value Code" := TempDimBufNew."Dimension Value Code";
                            TempDimSetEntry."Dimension Value ID" := DimVal."Dimension Value ID";
                            TempDimSetEntry.Insert;
                        until TempDimBufNew.Next = 0;
                    tmpGenJnlLine."Dimension Set ID" := DimMgt.GetDimensionSetID(TempDimSetEntry);
                end;
                AddSourceCurrency(GenJnlLine);
                OnBeforeGenJnlLineRunWithCheckInStatementPost(tmpGenJnlLine);
                GenJnlPostLine.RunWithCheck(tmpGenJnlLine);
                TotalSum := TotalSum + tmpGenJnlLine."Amount (LCY)" + tmpGenJnlLine."VAT Amount (LCY)";
            until TaxGenJnlPostingBuffer.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure PostDiscountBufferingTax(Len: Integer; AccountNo: Code[20]; DiscAmount: Decimal)
    var
        TempDimBuf: Record "Dimension Buffer" temporary;
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        SalesTypeCode: Code[20];
        EntryNo: Integer;
    begin
        TableID[1] := Database::Item;
        No[1] := Item."No.";
        TableID[2] := Database::"LSC Store";
        No[2] := Store."No.";
        TableID[3] := Database::"G/L Account";
        No[3] := AccountNo;
        GetDefaultDim(
            TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
            GlobalDimension2Code, Len);

        EntryNo := FindDimensions(TempDimBufNew);
        if EntryNo = 0 then
            EntryNo := InsertDimensions(TempDimBufNew);

        PostingBuffer[1]."Entry No." := EntryNo;
        PostingBuffer[1]."G/L Account" := AccountNo;
        PostingBuffer[1]."Department Code" := GlobalDimension1Code;
        PostingBuffer[1]."Project Code" := GlobalDimension2Code;

        PostingBuffer[1].Amount := DiscAmount;
        PostingBuffer[1]."VAT Base Amount" := DiscAmount;
        PostingBuffer[1]."VAT Amount" := 0;
        PostingBuffer[1]."Gen. Business Posting Group" := '';
        PostingBuffer[1]."Gen. Bus. Posting Group" := '';
        PostingBuffer[1]."Gen. Product Posting Group" := '';
        PostingBuffer[1]."Gen. Prod. Posting Group" := '';
        PostingBuffer[1]."VAT Business Posting Group" := '';
        PostingBuffer[1]."VAT. Bus. Posting Group" := '';
        PostingBuffer[1]."VAT Product Posting Group" := '';
        PostingBuffer[1]."VAT. Prod. Posting Group" := '';
        PostingBuffer[1].isDiscount := true;

        UpdPostingBuffer;
    end;

    [Scope('OnPrem')]
    procedure UpdTaxPostingBuffers(DocNumber: Code[20])
    var
        TransSalesTaxEntry: Record "LSC Trans. SalesTax Entry";
        TaxArea: Record "Tax Area";
        TaxJurisdiction: Record "Tax Jurisdiction";
        CurrExchRate: Record "Currency Exchange Rate";
        UseDate: Date;
        GlobalDimension1Code: Code[20];
        GlobalDimension2Code: Code[20];
        RemSalesTaxAmt: Decimal;
        RemSalesTaxSrcAmt: Decimal;
        EntryNo: Integer;
        Len: Integer;
        SalesTaxCountry: Option US,CA,,,,,,,,,,,,NoTax;
    begin
        TransSalesTaxEntryTemp.Reset;
        TransSalesTaxEntryTemp.SetRange("Store No.", Transaction."Store No.");
        TransSalesTaxEntryTemp.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        TransSalesTaxEntryTemp.SetRange("Transaction No.", Transaction."Transaction No.");
        if not TransSalesTaxEntryTemp.IsEmpty then
            exit;

        UseDate := Statement."Posting Date";
        RemSalesTaxAmt := 0;
        RemSalesTaxSrcAmt := 0;

        TransSalesTaxEntry.Reset;
        TransSalesTaxEntry.SetRange("Store No.", Transaction."Store No.");
        TransSalesTaxEntry.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
        TransSalesTaxEntry.SetRange("Transaction No.", Transaction."Transaction No.");
        if TransSalesTaxEntry.FindSet() then
            repeat
                if ((TransSalesTaxEntry."Tax Base Amount" <> 0) and (TransSalesTaxEntry."Tax Type" = TransSalesTaxEntry."Tax Type"::"Sales and Use Tax")) or
                   ((TransSalesTaxEntry.Quantity <> 0) and (TransSalesTaxEntry."Tax Type" = TransSalesTaxEntry."Tax Type"::"Excise Tax"))
                then begin
                    if TransSalesTaxEntry."Tax Area Code" = '' then
                        SalesTaxCountry := SalesTaxCountry::NoTax
                    else begin
                        TaxArea.Get(TransSalesTaxEntry."Tax Area Code");
                    end;

                    GenJnlLine.Init;
                    GenJnlLine."Posting Date" := Statement."Posting Date";
                    GenJnlLine."Document Date" := Statement."Posting Date";
                    GenJnlLine."Document Type" := GenJnlLine."Document Type"::" ";
                    GenJnlLine."Document No." := DocNumber;
                    GenJnlLine."External Document No." := Statement."Posting No.";
                    GenJnlLine."System-Created Entry" := true;
                    GenJnlLine.Amount := 0;
                    GenJnlLine."Source Currency Code" := Store."Currency Code";
                    GenJnlLine."Source Currency Amount" := 0;
                    GenJnlLine."Bill-to/Pay-to No." := Transaction."Customer No.";
                    GenJnlLine."Tax Area Code" := TransSalesTaxEntry."Tax Area Code";
                    GenJnlLine."Tax Group Code" := TransSalesTaxEntry."Tax Group Code";
                    GenJnlLine."Tax Liable" := TransSalesTaxEntry."Tax Liable";
                    GenJnlLine.Quantity := TransSalesTaxEntry.Quantity;
                    GenJnlLine."VAT Calculation Type" := GenJnlLine."VAT Calculation Type"::"Sales Tax";
                    GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
                    GenJnlLine."Source Code" := BackOfficeSetup."Source Code";

                    GenJnlLine."Source Curr. VAT Base Amount" := TransSalesTaxEntry."Tax Base Amount";
                    GenJnlLine."VAT Base Amount (LCY)" := Round(TransSalesTaxEntry."Tax Base Amount");
                    GenJnlLine."VAT Base Amount" := GenJnlLine."VAT Base Amount (LCY)";
                    OnBeforeSalesTaxCountryCheck(SalesTaxCountry, TaxArea);
                    if TaxJurisdiction.Code <> TransSalesTaxEntry."Tax Jurisdiction Code" then begin
                        TaxJurisdiction.Get(TransSalesTaxEntry."Tax Jurisdiction Code");
                        if SalesTaxCountry = SalesTaxCountry::CA then begin
                            RemSalesTaxAmt := 0;
                            RemSalesTaxSrcAmt := 0;
                        end;
                    end;
                    if TaxJurisdiction."Unrealized VAT Type" > 0 then begin
                        TaxJurisdiction.TestField("Unreal. Tax Acc. (Sales)");
                        GenJnlLine."Account No." := TaxJurisdiction."Unreal. Tax Acc. (Sales)";
                    end else begin
                        TaxJurisdiction.TestField("Tax Account (Sales)");
                        GenJnlLine."Account No." := TaxJurisdiction."Tax Account (Sales)";
                    end;
                    GLAccount.Get(GenJnlLine."Account No.");
                    GenJnlLine.Description := GLAccount.Name;
                    GenJnlLine."Gen. Posting Type" := GenJnlLine."Gen. Posting Type"::Sale;
                    if TransSalesTaxEntry."Tax Amount" <> 0 then begin
                        RemSalesTaxSrcAmt := RemSalesTaxSrcAmt +
                          CurrExchRate.ExchangeAmtLCYToFCY(UseDate, Store."Currency Code", TransSalesTaxEntry."Tax Amount", 1);
                        GenJnlLine."Source Curr. VAT Amount" := Round(RemSalesTaxSrcAmt, Currency."Amount Rounding Precision");
                        RemSalesTaxSrcAmt := RemSalesTaxSrcAmt - GenJnlLine."Source Curr. VAT Amount";
                        RemSalesTaxAmt := RemSalesTaxAmt + TransSalesTaxEntry."Tax Amount";
                        GenJnlLine."VAT Amount (LCY)" := Round(RemSalesTaxAmt);
                        RemSalesTaxAmt := RemSalesTaxAmt - GenJnlLine."VAT Amount (LCY)";
                        GenJnlLine."VAT Amount" := GenJnlLine."VAT Amount (LCY)";
                    end;
                    GenJnlLine."VAT Difference" := TransSalesTaxEntry."Tax Difference";

                    Clear(TableID);
                    Clear(No);
                    TableID[1] := Database::"LSC Store";
                    No[1] := Store."No.";
                    TableID[2] := Database::"G/L Account";
                    No[2] := GenJnlLine."Account No.";
                    Len := 2;
                    if Transaction."Customer No." <> '' then begin
                        TableID[3] := Database::Customer;
                        No[3] := Transaction."Customer No.";
                        Len := 3;
                    end;
                    GetDefaultDim(
                        TableID, No, BackOfficeSetup."Source Code", GlobalDimension1Code,
                        GlobalDimension2Code, Len);
                    EntryNo := FindDimensions(TempDimBufNew);
                    if EntryNo = 0 then
                        EntryNo := InsertDimensions(TempDimBufNew);
                    GenJnlLine."Shortcut Dimension 1 Code" := GlobalDimension1Code;
                    GenJnlLine."Shortcut Dimension 2 Code" := GlobalDimension2Code;
                    GenJnlLine."Line No." := EntryNo;
                    OnBeforeUpdGenJnlBuffer(GenJnlLine, TaxGenJnlPostingBuffer, Transaction, TransSalesTaxEntry);
                    UpdGenJnlBuffer();
                end;
            until TransSalesTaxEntry.Next = 0;

        TransSalesTaxEntryTemp.Init;
        TransSalesTaxEntryTemp."Store No." := Transaction."Store No.";
        TransSalesTaxEntryTemp."POS Terminal No." := Transaction."POS Terminal No.";
        TransSalesTaxEntryTemp."Transaction No." := Transaction."Transaction No.";
        TransSalesTaxEntryTemp.Insert;
    end;

    [Scope('OnPrem')]
    procedure UpdGenJnlBuffer()
    begin
        //Use Posting buffer - convert: Tax Type->Type,Tax Group Code->Gen Bus. Posting Group,Tax jurisdiction Code->Gen. Prod. Posting grou
        TaxGenJnlPostingBuffer."G/L Account" := GenJnlLine."Account No.";
        TaxGenJnlPostingBuffer."Gen. Business Posting Group" := GenJnlLine."Tax Group Code";
        TaxGenJnlPostingBuffer."Department Code" := GenJnlLine."Shortcut Dimension 1 Code";
        TaxGenJnlPostingBuffer."Project Code" := GenJnlLine."Shortcut Dimension 2 Code";
        TaxGenJnlPostingBuffer."Document No." := GenJnlLine."Document No.";
        TaxGenJnlPostingBuffer."Entry No." := GenJnlLine."Line No.";
        TaxGenJnlPostingBuffer."Tax Area Code" := GenJnlLine."Tax Area Code";
        TaxGenJnlPostingBuffer."Tax Group Code" := GenJnlLine."Tax Group Code";
        TaxGenJnlPostingBuffer."Tax Liable" := GenJnlLine."Tax Liable";

        if TaxGenJnlPostingBuffer.Find then begin
            tmpGenJnlLine.Get('', '', TaxGenJnlPostingBuffer.Int);
            tmpGenJnlLine.Quantity += GenJnlLine.Quantity;
            tmpGenJnlLine."Source Curr. VAT Base Amount" += GenJnlLine."Source Curr. VAT Base Amount";
            tmpGenJnlLine."VAT Base Amount (LCY)" += GenJnlLine."VAT Base Amount (LCY)";
            tmpGenJnlLine."VAT Base Amount" += GenJnlLine."VAT Base Amount";
            tmpGenJnlLine."Source Curr. VAT Amount" += GenJnlLine."Source Curr. VAT Amount";
            tmpGenJnlLine."VAT Amount (LCY)" += GenJnlLine."VAT Amount (LCY)";
            tmpGenJnlLine."VAT Amount" += GenJnlLine."VAT Amount";
            tmpGenJnlLine."VAT Difference" += GenJnlLine."VAT Difference";
            tmpGenJnlLine.Modify;
        end else begin
            if tmpGenJnlLine.FindLast() then;
            TaxGenJnlPostingBuffer.Int := tmpGenJnlLine."Line No." + 1;
            TaxGenJnlPostingBuffer.Insert;
            tmpGenJnlLine.Init;
            tmpGenJnlLine := GenJnlLine;
            tmpGenJnlLine."Line No." := TaxGenJnlPostingBuffer.Int;
            tmpGenJnlLine.Insert;
        end;
    end;

    [Scope('OnPrem')]
    procedure ChangeDistributeSalesTax(var TempSalesLineForSalesTax: Record "Sales Line" temporary)
    begin
        TempSalesLineForSalesTax."Document Type" := TempSalesLineForSalesTax."Document Type"::Order;
        TempSalesLineForSalesTax."Document No." := TaxPostingBuffer."Document No.";
        TempSalesLineForSalesTax."Line No." := 10000;
        TempSalesLineForSalesTax.Quantity := TaxPostingBuffer.Quantity;
        TempSalesLineForSalesTax."Qty. to Invoice" := TaxPostingBuffer.Quantity;
        TempSalesLineForSalesTax."Quantity (Base)" := TaxPostingBuffer.Quantity;
        TempSalesLineForSalesTax."Qty. to Invoice (Base)" := TaxPostingBuffer.Quantity;
        TempSalesLineForSalesTax."Line Amount" := TaxPostingBuffer."VAT Base Amount";
        TempSalesLineForSalesTax."Inv. Discount Amount" := TaxPostingBuffer."POS Inv. Disc. Amount";
        TempSalesLineForSalesTax."Tax Liable" := TaxPostingBuffer."Tax Liable";
        TempSalesLineForSalesTax."Tax Area Code" := TaxPostingBuffer."Tax Area Code";
        TempSalesLineForSalesTax."Tax Group Code" := TaxPostingBuffer."Tax Group Code";
        TempSalesLineForSalesTax.Insert;
    end;

    local procedure OpenTablesBuffers()
    var
        TransactionStatus: Record "LSC Transaction Status";
        RecRef: RecordRef;
    begin
        RecRef.GETTABLE(TransactionStatus);
        IF BufferUtility.IsBufferOpen(RecRef, 1) THEN
            BufferUtility.CloseBuffer(RecRef, 1);
        BufferUtility.OpenBuffer(RecRef, 1);
    end;

    local procedure FlushTablesBuffers()
    var
        TransactionStatusTmp: Record "LSC Transaction Status" temporary;
        TransactionStatus: Record "LSC Transaction Status";
        TransSalesEntryStatus: Record "LSC Trans. Sales Entry Status";
        RecRef: RecordRef;
    begin
        RecRef.GETTABLE(TransactionStatusTmp);
        BufferUtility.SetTableFilter(1, RecRef, 1);
        IF BufferUtility.FindFirstRec(1, RecRef, 1) THEN
            REPEAT
                RecRef.SETTABLE(TransactionStatusTmp);
                TransactionStatus.GET(TransactionStatusTmp."Store No.", TransactionStatusTmp."POS Terminal No.", TransactionStatusTmp."Transaction No.");
                TransactionStatus.TRANSFERFIELDS(TransactionStatusTmp, FALSE);
                TransactionStatus.MODIFY(TRUE);
                TransSalesEntryStatus.SETRANGE("Store No.", TransactionStatus."Store No.");
                TransSalesEntryStatus.SETRANGE("POS Terminal No.", TransactionStatus."POS Terminal No.");
                TransSalesEntryStatus.SETRANGE("Transaction No.", TransactionStatus."Transaction No.");
                TransSalesEntryStatus.MODIFYALL(Status, TransactionStatus.Status, TRUE);
                SetTransInvAdjmtEntryStatus(TransactionStatus);
            UNTIL BufferUtility.NextRec(1, 1, RecRef, 1) = 0;
        RecRef.GETTABLE(TransactionStatusTmp);
        BufferUtility.CloseBuffer(RecRef, 1);
    end;

    local procedure TransStatusToBuffer(VAR TransactionStatus: Record "LSC Transaction Status")
    var
        RecRef: RecordRef;
    begin
        RecRef.GETTABLE(TransactionStatus);
        BufferUtility.UpdateRec(RecRef, 1);
    end;

    local procedure GetTransStatusBuffer(VAR TransactionStatusTmp_p: Record "LSC Transaction Status" TEMPORARY)
    var
        TransactionStatusTmp: Record "LSC Transaction Status" temporary;
        RecRef: RecordRef;
    begin
        RecRef.GETTABLE(TransactionStatusTmp);
        BufferUtility.SetTableFilter(1, RecRef, 1);
        IF BufferUtility.FindFirstRec(1, RecRef, 1) THEN
            REPEAT
                RecRef.SETTABLE(TransactionStatusTmp);
                TransactionStatusTmp_p.INIT;
                TransactionStatusTmp_p := TransactionStatusTmp;
                TransactionStatusTmp_p.INSERT;
            Until BufferUtility.NextRec(1, 1, RecRef, 1) = 0;
    end;

    local procedure AddSourceCurrency(VAR GenJnlLine_l: Record "Gen. Journal Line")
    begin
        GenJnlLine_l."Source Currency Code" := GenJnlLine_l."Currency Code";
        GenJnlLine_l."Source Currency Amount" := GenJnlLine_l.Amount;
        GenJnlLine_l."Source Curr. VAT Base Amount" := GenJnlLine_l."VAT Base Amount";
        GenJnlLine_l."Source Curr. VAT Amount" := GenJnlLine_l."VAT Amount";
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeStatementPost(var Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessTransactionStatus(var TransactionStatus: Record "LSC Transaction Status"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessTransactionStatus(var TransactionStatus: Record "LSC Transaction Status"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessStatementLine(var StatementLine: Record "LSC Statement Line"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessStatementLine(var StatementLine: Record "LSC Statement Line"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessSafeStatementLine(var SafeStatementLine: Record "LSC Safe Statement Line"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessSafeStatementLine(var SafeStatementLine: Record "LSC Safe Statement Line"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessGLPostingBuffer(var PostingBuffer: Record "LSC Posting Buffer"; Statement: Record "LSC Statement"; var TempDimBufPost: Record "Dimension Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessPostingBuffer(var PostingBuffer: Record "LSC Posting Buffer"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessItemPostingBuffer(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterProcessItemPostingBuffer(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeEndProcessTransactionStatus(var TransactionStatus: Record "LSC Transaction Status"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeItemJnlLinePostLine(var ItemJournalLine: Record "Item Journal Line"; Statement: Record "LSC Statement"; var ItemPostingBuffer: Record "LSC Item Posting Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterItemJnlLinePostLine(var ItemJournalLine: Record "Item Journal Line"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterEndProcessTransactionStatus(var TransactionStatus: Record "LSC Transaction Status"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostItemSales(var TransSalesEntry: Record "LSC Trans. Sales Entry"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPostItemSales(var TransSalesEntry: Record "LSC Trans. Sales Entry"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRunItemPosting(var Statement: Record "LSC Statement"; UndoItemPosting: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterRunItemPosting(var Statement: Record "LSC Statement"; UndoItemPosting: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostItemAdjustment(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostItem(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostToCustomer(var Statement: Record "LSC Statement"; var TransactionHeader: Record "LSC Transaction Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPostToCustomer(var Statement: Record "LSC Statement"; var TransactionHeader: Record "LSC Transaction Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGenJnlPostLine(var GenJournalLine: Record "Gen. Journal Line"; var Statement: Record "LSC Statement"; var TransactionHeader: Record "LSC Transaction Header")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeMakeOrder(var TransSalesEntry: Record "LSC Trans. Sales Entry"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeModifySalesHeaderInMakeOrder(var SalesHeader: Record "Sales Header"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterMakeOrder(var SalesHeader: Record "Sales Header"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostItemSalesExit(var TransSalesEntry: Record "LSC Trans. Sales Entry"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdatePaymentBuffer(var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterStatementPost(var Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateDocNo(var DocNo: Code[50])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateDocNo(var DocNo: Code[50])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdateItemPostingBuffer(var ItemPostingBuffer: Record "LSC Item Posting Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertItemPostingBufferSales(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; var TransSalesEntry: Record "LSC Trans. Sales Entry"; var TransactionHeader: Record "LSC Transaction Header");
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertBOMPostingBufferSales(var BOMPostingBuffer: Record "LSC BOM Posting Buffer"; var TransSalesEntry: Record "LSC Trans. Sales Entry");
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostNegAdj(var ItemPostingBuffer: Record "LSC Item Posting Buffer"; var TransInventoryEntry: Record "LSC Trans. Inventory Entry"; var TransactionHeader: Record "LSC Transaction Header");
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRetailBOMJnlPostLine(var RetailBOMJnlLine: Record "LSC Retail BOM Journal Line"; var BOMPostingBuffer: Record "LSC BOM Posting Buffer");
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRetailBOMJnlPostBOMCompLine(var RetailBOMJnlLine: Record "LSC Retail BOM Journal Line"; var Store: Record "LSC Store");
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalculateRoundingDifference(var Statement: Record "LSC Statement"; var GenJnlLine: Record "Gen. Journal Line"; var TotalSum: Decimal)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeProcessPostingBuffer(var GenJnlLine: Record "Gen. Journal Line"; var PostingBuffer: Record "LSC Posting Buffer"; var Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeSalesTaxCountryCheck(var SalesTaxCountry: Option US,CA,,,,,,,,,,,,NoTax; TaxArea: Record "Tax Area")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdGenJnlBuffer(var GenJournalLine: Record "Gen. Journal Line"; var PostingBuffer: Record "LSC Posting Buffer" temporary; TransactionHeader: Record "LSC Transaction Header"; TransSalesTaxEntry: Record "LSC Trans. SalesTax Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostIncomeExpLine(var TransIncomeExpenseEntry: Record "LSC Trans. Inc./Exp. Entry"; TransactionHeader: Record "LSC Transaction Header"; Statement: Record "LSC Statement"; DocNumber: Code[20]; var PostingBuffer: Record "LSC Posting Buffer" temporary; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforePostCustomerStatementLine(Statement: Record "LSC Statement"; var StatementLine: Record "LSC Statement Line"; var GenJnlLine: Record "Gen. Journal Line"; var TotalSum: Decimal)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGenJnlLineRunWithCheckInStatementPost(var GenJnlLine: Record "Gen. Journal Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdPostingBufferInPostIncomeExpLine(var PostingBuffer: Record "LSC Posting Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetVATPostingSetup(var VATPostingSetup: Record "VAT Posting Setup"; var Transaction: Record "LSC Transaction Header"; var TransSalesEntry: Record "LSC Trans. Sales Entry"; var GenPostingSetup: Record "General Posting Setup")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdPostingBufferInPostIncomeExpLine2(var PostingBuffer: Record "LSC Posting Buffer"; var TransIncomeExpenseEntry: Record "LSC Trans. Inc./Exp. Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFindDimensions(var Statement: Record "LSC Statement"; var DimBuf: Record "Dimension Buffer"; var TempDimBufPost: Record "Dimension Buffer" temporary; var IsHandled: boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetDefaultDim(var Statement: Record "LSC Statement"; var TableID: array[10] of Integer; var No: array[10] of Code[20]; var GlobalDim1Code: Code[20]; var GlobalDim2Code: Code[20]; var Len: Integer; var TransactionHeader: Record "LSC Transaction Header"; TransSalesEntry: Record "LSC Trans. Sales Entry"; var IsHandled: boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdPostingBufferInPostItemSales(var PostingBuffer: Record "LSC Posting Buffer"; var TransSalesEntry: Record "LSC Trans. Sales Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterSalesLineModify(var SalesLine: Record "Sales Line"; var TransSalesEntry: Record "LSC Trans. Sales Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnUpdateGnlSafeRefNo(var pGenJnlLine: Record "Gen. Journal Line"; pSafeStatementLine: Record "LSC Safe Statement Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInsertPostedStatementLine(StatementLine: Record "LSC Statement Line"; var PostedStatementLine: Record "LSC Posted Statement Line")
    begin
    end;

    procedure SafeManagementCheck(Statement_p: Record "LSC Statement") ProceedWithPosting: Boolean
    var
        Store_l: Record "LSC Store";
        Transaction_l: Record "LSC Transaction Header";
        Transaction2_l: Record "LSC Transaction Header";
        TransactionStatus_l: Record "LSC Transaction Status";
        StatementLine_l: Record "LSC Statement Line";
        StatementLineTemp: Record "LSC Statement Line" temporary;
        SafeStatementLine_l: Record "LSC Safe Statement Line";
        TmpEndOfDayEntry: Record "LSC POS Start Status" temporary;
        POSTerminal_l: Record "LSC POS Terminal";
        POSTerminalTemp: Record "LSC POS Terminal" temporary;
        StatementCalculate: Codeunit "LSC Statement-Calculate";
        IsMissingEndOfDay: Boolean;
        IsCheckEOD: Boolean;
    begin
        if Store_l.Get(Statement_p."Store No.") then
            if Store_l."Safe Mgnt. in Use" then begin
                if Statement_p."Closing Method" = Statement_p."Closing Method"::"Date and Time" then begin
                    Transaction_l.SetCurrentKey("Store No.", Date);
                    Transaction_l.SetRange("Store No.", Statement_p."Store No.");
                    Transaction_l.SetRange(Date, Statement_p."Trans. Starting Date", Statement_p."Trans. Ending Date");
                end else
                    if Statement_p."Closing Method" = Statement_p."Closing Method"::Shift then begin
                        Transaction_l.SetCurrentKey("Store No.", "Shift Date", "Shift No.");
                        Transaction_l.SetRange("Store No.", Statement_p."Store No.");
                        Transaction_l.SetRange("Shift Date", Statement_p."Shift Date");
                        Transaction_l.SetRange("Shift No.", Statement_p."Shift No.");
                    end;
                Transaction2_l.Copy(Transaction_l);
                Transaction_l.SetRange("Transaction Type", Transaction_l."Transaction Type"::"Tender Decl.");
                Transaction_l.SetRange("Entry Status", Transaction_l."Entry Status"::" ");
                Transaction_l.SetAutoCalcFields("Statement No.");
                if Transaction_l.FindSet() then
                    repeat
                        if Transaction_l."Statement No." = Statement_p."No." then
                            StatementCalculate.FindLastTenderDecl(Transaction_l, Store_l, Statement_p."No.");
                    until Transaction_l.Next() = 0;
                StatementCalculate.GetTenderDeclareEntries(TmpEndOfDayEntry);

                //Populate all POSes that require tender declaration
                POSTerminal_l.SetRange("Store No.", Store_l."No.");
                POSTerminal_l.SetRange("Exclude from Cash Mgnt.", false);
                if POSTerminal_l.FindSet() then
                    repeat
                        POSTerminalTemp := POSTerminal_l;
                        if POSTerminal_l."Terminal Statement" then
                            if POSTerminal_l."Statement Method" = Store_l."Statement Method" then
                                POSTerminalTemp."Terminal Statement" := false;
                        POSTerminalTemp.Insert();
                    until POSTerminal_l.Next() = 0;

                //Populate unique Staff/POS ID in Statement Lines
                StatementLine_l.SetRange("Statement No.", Statement_p."No.");
                if StatementLine_l.FindSet() then
                    repeat
                        StatementLineTemp.SetRange("Statement No.", StatementLine_l."Statement No.");
                        StatementLineTemp.SetRange("Statement Code", StatementLine_l."Statement Code");
                        StatementLineTemp.SetRange("Staff ID", StatementLine_l."Staff ID");
                        StatementLineTemp.SetRange("POS Terminal No.", StatementLine_l."POS Terminal No.");
                        if StatementLineTemp.IsEmpty() then begin
                            StatementLineTemp := StatementLine_l;
                            StatementLineTemp."Counting Required" := false; //Marker for release
                            StatementLineTemp.Insert();
                        end;
                    until StatementLine_l.Next() = 0;

                TransactionStatus_l.Reset;
                TransactionStatus_l.SetCurrentKey("Statement No.");
                TransactionStatus_l.SetRange("Statement No.", Statement_p."No.");
                TmpEndOfDayEntry.SetRange("Store No.", Statement_p."Store No.");
                IsMissingEndOfDay := false;
                StatementLineTemp.Reset();
                if StatementLineTemp.FindSet(true, false) then
                    repeat
                        IsCheckEOD := false;
                        POSTerminalTemp.Reset();

                        if (StatementLineTemp."POS Terminal No." = '') and (StatementLineTemp."Staff ID" = '') then begin
                            //Method::Total
                            TmpEndOfDayEntry.SetRange(Type, TmpEndOfDayEntry.Type::Staff);
                            if Store_l."Statement Method" <> Store_l."Statement Method"::Total then begin
                                POSTerminalTemp.SetRange("Terminal Statement", true);
                                POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::Total);
                            end else
                                POSTerminalTemp.SetRange("Terminal Statement", false);
                            if POSTerminalTemp.FindSet() then
                                repeat
                                    TransactionStatus_l.SetRange("POS Terminal No.", POSTerminalTemp."No.");
                                    if not TransactionStatus_l.IsEmpty() then
                                        IsCheckEOD := true;
                                until (POSTerminalTemp.Next() = 0) or IsCheckEOD;
                        end else
                            if StatementLineTemp."Staff ID" <> '' then begin
                                //Method::Staff
                                TmpEndOfDayEntry.SetRange(Type, TmpEndOfDayEntry.Type::Staff);
                                if Store_l."Statement Method" <> Store_l."Statement Method"::Staff then begin
                                    POSTerminalTemp.SetRange("Terminal Statement", true);
                                    POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::Staff);
                                end else
                                    POSTerminalTemp.SetRange("Terminal Statement", false);
                                if POSTerminalTemp.FindSet() then
                                    repeat
                                        TransactionStatus_l.SetRange("POS Terminal No.", POSTerminalTemp."No.");
                                        if TransactionStatus_l.FindSet() then
                                            repeat
                                                if Transaction_l.Get(Statement_p."Store No.", POSTerminalTemp."No.", TransactionStatus_l."Transaction No.") then
                                                    if StatementLineTemp."Statement Code" = Transaction_l."Staff ID" then
                                                        IsCheckEOD := true;
                                            until (TransactionStatus_l.Next() = 0) or IsCheckEOD;
                                    until (POSTerminalTemp.Next() = 0) or IsCheckEOD;
                            end else
                                if StatementLineTemp."POS Terminal No." <> '' then begin
                                    //Method::POS Terminal
                                    TmpEndOfDayEntry.SetRange(Type, TmpEndOfDayEntry.Type::"POS Terminal");
                                    if Store_l."Statement Method" <> Store_l."Statement Method"::"POS Terminal" then begin
                                        POSTerminalTemp.SetRange("Terminal Statement", true);
                                        POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::"POS Terminal");
                                    end else
                                        POSTerminalTemp.SetRange("Terminal Statement", false);
                                    POSTerminalTemp.SetRange("No.", StatementLineTemp."Statement Code");
                                    if not POSTerminalTemp.IsEmpty() then
                                        IsCheckEOD := true;
                                end;

                        if IsCheckEOD then begin
                            TmpEndOfDayEntry.SetRange(Id, StatementLineTemp."Statement Code");
                            if TmpEndOfDayEntry.IsEmpty() then begin
                                IsMissingEndOfDay := true;
                                StatementLineTemp."Counting Required" := true;
                                StatementLineTemp.Modify();
                            end;
                        end;
                    until StatementLineTemp.Next() = 0;
                if IsMissingEndOfDay then begin
                    StatementLineTemp.Reset();
                    StatementLineTemp.SetRange("Counting Required", false);
                    if StatementLineTemp.IsEmpty() then begin
                        Message(StatementNotReadyMsg);
                        exit(false);
                    end;
                    Exit(false);
                    StatementLineTemp.Reset();
                    StatementLineTemp.SetRange("Counting Required", true);
                    Transaction2_l.SetAutoCalcFields("Statement No.");
                    if StatementLineTemp.FindSet() then
                        repeat
                            POSTerminalTemp.Reset();
                            if (StatementLineTemp."POS Terminal No." = '') and (StatementLineTemp."Staff ID" = '') then begin
                                //Method::Total
                                if Store_l."Statement Method" <> Store_l."Statement Method"::Total then begin
                                    POSTerminalTemp.SetRange("Terminal Statement", true);
                                    POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::Total);
                                end else
                                    POSTerminalTemp.SetRange("Terminal Statement", false);
                                if Transaction2_l.FindSet() then
                                    repeat
                                        if (Transaction2_l."Statement No." = Statement_p."No.") then begin
                                            POSTerminalTemp.SetRange("No.", Transaction2_l."POS Terminal No.");
                                            if not POSTerminalTemp.IsEmpty() then
                                                ReleaseTransactions(Transaction2_l);
                                        end;
                                    until Transaction2_l.Next() = 0;
                            end else
                                if StatementLineTemp."Staff ID" <> '' then begin
                                    //Method::Staff
                                    if Store_l."Statement Method" <> Store_l."Statement Method"::Staff then begin
                                        POSTerminalTemp.SetRange("Terminal Statement", true);
                                        POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::Staff);
                                    end else
                                        POSTerminalTemp.SetRange("Terminal Statement", false);
                                    if Transaction2_l.FindSet() then
                                        repeat
                                            if (Transaction2_l."Statement No." = Statement_p."No.") and (Transaction2_l."Staff ID" = StatementLineTemp."Staff ID") then begin
                                                POSTerminalTemp.SetRange("No.", Transaction2_l."POS Terminal No.");
                                                if not POSTerminalTemp.IsEmpty() then
                                                    ReleaseTransactions(Transaction2_l);
                                            end;
                                        until Transaction2_l.Next() = 0;
                                end else
                                    if StatementLineTemp."POS Terminal No." <> '' then begin
                                        //Method::POS Terminal
                                        if Store_l."Statement Method" <> Store_l."Statement Method"::"POS Terminal" then begin
                                            POSTerminalTemp.SetRange("Terminal Statement", true);
                                            POSTerminalTemp.SetRange("Statement Method", POSTerminalTemp."Statement Method"::"POS Terminal");
                                        end else
                                            POSTerminalTemp.SetRange("Terminal Statement", false);
                                        if Transaction2_l.FindSet() then
                                            repeat
                                                if (Transaction2_l."Statement No." = Statement_p."No.") and (Transaction2_l."POS Terminal No." = StatementLineTemp."POS Terminal No.") then begin
                                                    POSTerminalTemp.SetRange("No.", Transaction2_l."POS Terminal No.");
                                                    if not POSTerminalTemp.IsEmpty() then
                                                        ReleaseTransactions(Transaction2_l);
                                                end;
                                            until Transaction2_l.Next() = 0;
                                    end;
                            StatementLine_l.SetRange("Statement No.", StatementLineTemp."Statement No.");
                            StatementLine_l.SetRange("Statement Code", StatementLineTemp."Statement Code");
                            StatementLine_l.SetRange("Staff ID", StatementLineTemp."Staff ID");
                            StatementLine_l.SetRange("POS Terminal No.", StatementLineTemp."POS Terminal No.");
                            StatementLine_l.DeleteAll(true);
                            SafeStatementLine_l.SetRange("Statement No.", StatementLineTemp."Statement No.");
                            SafeStatementLine_l.SetRange("Statement Code", StatementLineTemp."Statement Code");
                            SafeStatementLine_l.SetRange("Staff ID", StatementLineTemp."Staff ID");
                            SafeStatementLine_l.SetRange("POS Terminal No.", StatementLineTemp."POS Terminal No.");
                            SafeStatementLine_l.DeleteAll(true);
                        until StatementLineTemp.Next() = 0;
                    Message(PostingReadyMsg);
                    exit(false);
                end;
            end;
        exit(true);
    end;

    local procedure ReleaseTransactions(TransactionHeader_p: Record "LSC Transaction Header")
    var
        TransactionStatus_l: Record "LSC Transaction Status";
        TransSalesEntryStatus_l: Record "LSC Trans. Sales Entry Status";
    begin
        if TransactionStatus_l.Get(TransactionHeader_p."Store No.", TransactionHeader_p."POS Terminal No.", TransactionHeader_p."Transaction No.") then begin
            TransactionStatus_l."Statement No." := '';
            TransactionStatus_l.Modify(true);
        end;
        TransSalesEntryStatus_l.Reset;
        TransSalesEntryStatus_l.SetRange("Store No.", TransactionHeader_p."Store No.");
        TransSalesEntryStatus_l.SetRange("POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        TransSalesEntryStatus_l.SetRange("Transaction No.", TransactionHeader_p."Transaction No.");
        TransSalesEntryStatus_l.ModifyAll("Statement No.", '', true);
    end;

    local procedure AssignPostingGrIds(var PostingBuffer: Record "LSC Posting Buffer")
    begin
        IF LastPostingGrId = '' then
            LastPostingGrId := 'GRID000000';
        IF GenBusPostingGrId.ContainsKey(PostingBuffer."Gen. Business Posting Group") then
            PostingBuffer."Gen. Bus. Posting Group" := GenBusPostingGrId.get(PostingBuffer."Gen. Business Posting Group")
        else begin
            LastPostingGrId := IncStr(LastPostingGrId);
            PostingBuffer."Gen. Bus. Posting Group" := LastPostingGrId;
            GenBusPostingGrId.add(PostingBuffer."Gen. Business Posting Group", PostingBuffer."Gen. Bus. Posting Group");
        end;
        IF GenProductPostingGrId.ContainsKey(PostingBuffer."Gen. Product Posting Group") then
            PostingBuffer."Gen. Prod. Posting Group" := GenProductPostingGrId.get(PostingBuffer."Gen. Product Posting Group")
        else begin
            LastPostingGrId := IncStr(LastPostingGrId);
            PostingBuffer."Gen. Prod. Posting Group" := LastPostingGrId;
            GenProductPostingGrId.add(PostingBuffer."Gen. Product Posting Group", PostingBuffer."Gen. Prod. Posting Group");
        end;
        IF VATBusPostingGrId.ContainsKey(PostingBuffer."VAT Business Posting Group") then
            PostingBuffer."VAT. Bus. Posting Group" := VATBusPostingGrId.get(PostingBuffer."VAT Business Posting Group")
        else begin
            LastPostingGrId := IncStr(LastPostingGrId);
            PostingBuffer."VAT. Bus. Posting Group" := LastPostingGrId;
            VATBusPostingGrId.add(PostingBuffer."VAT Business Posting Group", PostingBuffer."VAT. Bus. Posting Group");
        end;
        IF VATProductPostingGrid.ContainsKey(PostingBuffer."VAT Product Posting Group") then
            PostingBuffer."VAT. Prod. Posting Group" := VATProductPostingGrid.get(PostingBuffer."VAT Product Posting Group")
        else begin
            LastPostingGrId := IncStr(LastPostingGrId);
            PostingBuffer."VAT. Prod. Posting Group" := LastPostingGrId;
            VATProductPostingGrid.add(PostingBuffer."VAT Product Posting Group", PostingBuffer."VAT. Prod. Posting Group");
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeModifySalesLine(var SalesLine: Record "Sales Line"; TransactionHeader: Record "LSC Transaction Header"; TransSalesEntry: Record "LSC Trans. Sales Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCheckDifference(Statement: Record "LSC Statement"; Store: Record "LSC Store"; RunningFromBatchPosting: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeDeleteStatement(var Statement: Record "LSC Statement")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterStatementPostBeforeCommit(var Statement: Record "LSC Statement")
    begin
    end;
}