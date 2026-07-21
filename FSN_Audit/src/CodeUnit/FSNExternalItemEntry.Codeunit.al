codeunit 50084 "FSN External Item Entry"
{
    Permissions = TableData "Job Queue Entry" = rimd,
                  TableData "Job Queue Log Entry" = rimd,
                  TableData "Item Journal Template" = imd,
                  TableData "Item Journal Batch" = imd;
    TableNo = "Job Queue Entry";

    var
        TemplateName, BatchName : Code[20];
        LastEntryNo: Integer;
        Text001: Label 'No se ha configurado la Cadena Parametros';
        Text002: Label 'El 4 parametro de AplicarAutomaticamenteDiario debe ser: Yes / No';
        Text003: Label 'La Cadena de Parametros requiere 4 valores requeridos separados por comas: TipoDocumento,PlantillaDiario,SeccionDiario,AplicarAutomaticamenteDiario: (Si / No), (Opcional) NoDocumento';
        Text004: Label 'Mov. EBS procesado por Skip Entry Configurado en FSN External Catalog';
        Text005: Label 'Mov. EBS reactivado por Skip Entry Configurado en FSN External Catalog';
        Text006: Label 'Item Journal Template %1 does not exist.';
        Text007: Label 'Item Journal Batch %1 does not exist.';
        Text008: Label 'Esta linea no esta incluida en el diario ';
        Text009: Label 'El campo [%1]=[%2] no coincide con el [%3].[%4]=[%5]';
        Text010: Label 'El [%1]=[%2] tiene más de un registro en BC: %3';
        Text011: Label 'El campo %1 no puede estar vacio';
        Text012: Label 'En el campo [%1] de la tabla [%2] este valor [%3]=[%4] no existe';
        Text013: Label 'Registro no puede ser procesado por Subinventoy = %1 and Transfer Subinventrory = %2';
        Text014: Label 'El campo [%1]=[%2] no tiene configurado un [%3].[%4]';
        Text015: Label 'entry no_ %1';

    trigger OnRun()
    var
        ItemLedgEntryType: Enum "Item Ledger Entry Type";
        ItemLedgDocType: Enum "Item Ledger Document Type";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLn: Record "Item Journal Line";
        ParameterList: List of [Text];
        EntryType: Text;
        DocumentType: Text;
        DocumentNo: Code[20];
        PostAutomatically: Boolean;
        FSNCatalgNo: Integer;
        SkipEntry: Boolean;
        ShowDialog: Boolean;
    begin
        //DocRef:001 Documentacion Tipo Movimiento y Tipo Documento

        ParameterList := Rec."Parameter String".Split(',');
        if ParameterList.Count() = 0 then
            Error(Text001);
        //case ParameterList.Count() of
        if ParameterList.Count() = 3 then begin
            DocumentType := ParameterList.Get(1);
            EVALUATE(FSNCatalgNo, ParameterList.Get(2));
            EVALUATE(SkipEntry, ParameterList.Get(3));
        end;
        if ParameterList.Count() = 4 then begin
            DocumentType := ParameterList.Get(1);
            TemplateName := ParameterList.Get(2);
            BatchName := ParameterList.Get(3);
            if ParameterList.Get(4) = 'Si' then
                PostAutomatically := true
            else
                if ParameterList.Get(4) = 'No' then
                    PostAutomatically := false
                else
                    Error(Text002);
        end;
        if ParameterList.Count() = 5 then begin
            DocumentType := ParameterList.Get(1);
            TemplateName := ParameterList.Get(2);
            BatchName := ParameterList.Get(3);
            if ParameterList.Get(4) = 'Si' then
                PostAutomatically := true
            else
                if ParameterList.Get(4) = 'No' then
                    PostAutomatically := false
                else
                    Error(Text002);
            DocumentNo := ParameterList.Get(5);
        end;
        if ParameterList.Count() = 6 then begin
            DocumentType := ParameterList.Get(1);
            TemplateName := ParameterList.Get(2);
            BatchName := ParameterList.Get(3);
            if ParameterList.Get(4) = 'Si' then
                PostAutomatically := true
            else
                if ParameterList.Get(4) = 'No' then
                    PostAutomatically := false
                else
                    Error(Text002);
            DocumentNo := ParameterList.Get(5);
            if ParameterList.Get(6) = 'Si' then
                ShowDialog := true;

        end;

        case DocumentType of
            'SkipEntry':
                begin
                    SkipEntry();
                end;
            'SkipEntryChangeFalse':
                begin
                    SkipEntry();
                end;
            '4':
                begin
                    CheckJrnlTemplateAndClearItemJrnl(ItemJnlTemplate, ItemJnlBatch, ItemJnlLn, TemplateName, BatchName);
                    CheckExternalItemEntryToApplyOnlyFullDocuments(ItemLedgEntryType::Transfer, ItemLedgDocType::"Direct Transfer", ItemJnlTemplate, ItemJnlBatch, PostAutomatically, DocumentNo, ShowDialog);
                end;
            '5':
                begin
                    CheckExternalItemEntryToApplyOnlyFullDocuments(ItemLedgEntryType::Purchase, ItemLedgDocType::"Purchase Receipt", ItemJnlTemplate, ItemJnlBatch, PostAutomatically, DocumentNo, ShowDialog);
                end;
            '7':
                begin
                    CheckExternalItemEntryToApplyOnlyFullDocuments(ItemLedgEntryType::Purchase, ItemLedgDocType::"Purchase Return Shipment", ItemJnlTemplate, ItemJnlBatch, PostAutomatically, DocumentNo, ShowDialog);
                end;
            '10':
                begin
                    Transfer();
                end;
            '20':
                begin
                    CheckJrnlTemplateAndClearItemJrnl(ItemJnlTemplate, ItemJnlBatch, ItemJnlLn, TemplateName, BatchName);
                    CheckExternalItemEntryToApplyOnlyFullDocuments(ItemLedgEntryType::"Positive Adjmt.", ItemLedgDocType::" ", ItemJnlTemplate, ItemJnlBatch, PostAutomatically, DocumentNo, ShowDialog);
                end;
            '21':
                begin
                    CheckJrnlTemplateAndClearItemJrnl(ItemJnlTemplate, ItemJnlBatch, ItemJnlLn, TemplateName, BatchName);
                    CheckExternalItemEntryToApplyOnlyFullDocuments(ItemLedgEntryType::"Negative Adjmt.", ItemLedgDocType::" ", ItemJnlTemplate, ItemJnlBatch, PostAutomatically, DocumentNo, ShowDialog);
                end;
            '22':
                begin
                    CatalogSkipEntryChange(FSNCatalgNo, SkipEntry);
                end;
        end;
    end;

    local procedure CatalogSkipEntryChange(FsnCatalogoNo: Integer; FSNSkipEntry: Boolean)
    var
        FSNExternalCatalog: Record "FSN External Catalog";
    begin
        FSNExternalCatalog.Reset();
        FSNExternalCatalog.SetFilter("No.", '%1', FsnCatalogoNo);
        if FSNExternalCatalog.FindFirst() then begin
            FSNExternalCatalog."Skip Entry" := FSNSkipEntry;
            FSNExternalCatalog.Modify();
            Message('El campo Skip Entry del catalogo %1 ha sido cambiado a %2', FSNExternalCatalog."No.", FSNSkipEntry);
        end;
    end;

    local procedure SkipEntry()
    var
        FSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalCatalog: Record "FSN External Catalog";
    begin
        FSNExternalItemEntry.Reset();
        FSNExternalCatalog.Reset();
        FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
        FSNExternalCatalog.SetRange("Skip Entry", true);
        if FSNExternalCatalog.FindFirst() then begin
            FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
            FSNExternalItemEntry.SetRange(Done, false);
            if FSNExternalItemEntry.FindSet() then begin
                repeat
                    FSNExternalItemEntry.Done := true;
                    FSNExternalItemEntry."Apply Entry" := false;
                    FSNExternalItemEntry."Last error" := Text004;
                    FSNExternalItemEntry.Modify();
                until FSNExternalItemEntry.Next() = 0;
            end;
        end;
    end;

    local procedure SkipEntryChangeFalse()
    var
        FSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalCatalog: Record "FSN External Catalog";
    begin
        FSNExternalItemEntry.Reset();
        FSNExternalCatalog.Reset();
        FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
        FSNExternalCatalog.SetRange("Skip Entry", false);
        if FSNExternalCatalog.FindFirst() then begin
            FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
            FSNExternalItemEntry.SetRange(Done, true);
            FSNExternalItemEntry.SetRange("No. Mov. BC", 0);
            if FSNExternalItemEntry.FindSet() then begin
                repeat
                    FSNExternalItemEntry.Done := false;
                    FSNExternalItemEntry."Apply Entry" := false;
                    FSNExternalItemEntry."Last error" := Text005;
                    FSNExternalItemEntry.Modify();
                until FSNExternalItemEntry.Next() = 0;
            end;
        end;
    end;

    local procedure CheckExternalItemEntryToApplyOnlyFullDocuments(
        EntryType: Enum "Item Ledger Entry Type";
        DocumentType: Enum "Item Ledger Document Type";
        var ItemJnlTemplate: Record "Item Journal Template";
        var ItemJnlBatch: Record "Item Journal Batch";
        var PostAutomatically: Boolean;
        var DocumentNo: Code[20];
        ShowDialog: Boolean)
    var
        FSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalItemEntryTransf, FSNExternalItemEntryTransfM : Record "FSN External Item Entry";
        FSNExtItemEntryTransf, FSNExtItemEntryTransfM, FSNExtItemEntryTrMOD : Record "FSN External Item Entry";
        CountExterItemEntryByDocument: Record "FSN External Item Entry";
        ModOldExterItemEntryByDocument, ModOldExterItemEntryByDocumentC : Record "FSN External Item Entry";
        PostFSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalCatLocation: Record "FSN External Catalog";
        FSNExternalCatLocationTo: Record "FSN External Catalog";
        FSNExternalCatalog: Record "FSN External Catalog";
        Item: Record Item;
        ItemUMP: Record "Item Unit of Measure";
        PurchHdr: Record "Purchase Header";
        PurchPostYesNo: Codeunit "Purch.-Post (Yes/No)";
        PurchaseConf: Record "Purchases & Payables Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        ItemExternalLines: Dictionary of [Code[20], Code[20]];
        ItemQtyExternalLines: Dictionary of [Code[20], Integer];
        QtyBase: Decimal;
        breakExternalEntry: Boolean;
        CountDocumentLine: Integer;
        TotalDocumentLine: Integer;
        ApplyFullDocument: Boolean;
        PrevDocumentNo: Code[20];
        PrevSubinventoy: Code[20];
        PrevPostingDate: Date;
        Progress: Dialog;
        ProgressMsg: Label 'Procesando: #1 de #2 ###############';
        CountEntry: Integer;
        WindowIsOpen: Boolean;
    begin
        FSNExternalCatalog.Reset();
        FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
        FSNExternalCatalog.SetRange("Skip Entry", false);
        FSNExternalCatalog.SetRange("BC Entry Type", EntryType);
        FSNExternalCatalog.SetRange("BC Document Type", DocumentType);
        if FSNExternalCatalog.FindSet() then begin
            repeat
                FSNExternalItemEntry.Reset();
                FSNExternalItemEntry.SetCurrentKey("Posting Date", Subinventoy, "Document No.", "Order Line No.");
                FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                FSNExternalItemEntry.SetRange(Done, false);
                FSNExternalItemEntry.SetFilter(Quantity, '<>%1', 0);
                FSNExternalItemEntry.SetFilter("Apply Entry", '<>%1', true);
                if DocumentNo <> '' then begin
                    if DocumentType = DocumentType::"Direct Transfer" then
                        FSNExternalItemEntry.SetRange("Source No.", DocumentNo)
                    else
                        FSNExternalItemEntry.SetRange("Document No.", DocumentNo);
                end else begin
                    case DocumentType of
                        DocumentType::"Purchase Receipt":
                            begin
                                FSNExternalItemEntry.SetFilter("Document No.", '<>%1', '');
                            end;
                        DocumentType::"Purchase Return Shipment", DocumentType::" ":
                            begin
                                FSNExternalItemEntry.SetFilter(Subinventoy, '<>%1', '');
                            end;
                        DocumentType::"Direct Transfer":
                            begin
                                FSNExternalItemEntryTransfM.CopyFilters(FSNExternalItemEntry);
                                FSNExternalItemEntryTransfM.ModifyAll("Last error", '', false);
                                ModOldExterItemEntryByDocument.CopyFilters(FSNExternalItemEntry);
                                ModOldExterItemEntryByDocument.SetFilter("Source No.", '<>%1', '');
                                ModOldExterItemEntryByDocument.SetFilter(Quantity, '<%1', 0);
                                if ModOldExterItemEntryByDocument.Find('-') then begin
                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, ModOldExterItemEntryByDocument.Count(), false);
                                    repeat
                                        if ModOldExterItemEntryByDocument.Subinventoy = ModOldExterItemEntryByDocument."Transfer Subinventory" then begin
                                            ModOldExterItemEntryByDocument."Last error" := 'Registro no puede ser procesado por Subinventoy = Transfer Subinventory';
                                            ModOldExterItemEntryByDocument."Apply Entry" := true;
                                            ModOldExterItemEntryByDocumentC.Done := true;
                                            ModOldExterItemEntryByDocument.Modify();
                                            ModOldExterItemEntryByDocumentC.Reset();
                                            ModOldExterItemEntryByDocumentC.SetFilter("Entry No.", '%1', ConvertCodeToInteger(ModOldExterItemEntryByDocument."Source No."));
                                            if ModOldExterItemEntryByDocumentC.FindFirst() then begin
                                                ModOldExterItemEntryByDocument."Apply Entry" := true;
                                                ModOldExterItemEntryByDocumentC."Last error" := 'Registro no puede ser procesado por Subinventoy = Transfer Subinventory';
                                                ModOldExterItemEntryByDocumentC.Done := true;
                                                ModOldExterItemEntryByDocumentC.Modify();
                                            end;
                                        end;
                                        ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, false);
                                        CountEntry += 1;
                                    until ModOldExterItemEntryByDocument.Next() = 0;
                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, true);
                                end;

                                FSNExtItemEntryTransf.CopyFilters(FSNExternalItemEntry);
                                FSNExtItemEntryTransf.SetFilter("Source No.", '<>%1', '');
                                FSNExtItemEntryTransf.SetFilter(Quantity, '<%1', 0);
                                if FSNExtItemEntryTransf.Find('-') then begin
                                    repeat
                                        // Verificar duplicados: entrada y salidas con mismo Source No.
                                        FSNExtItemEntryTransfM.Reset();
                                        FSNExtItemEntryTransfM.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                        FSNExtItemEntryTransfM.SetRange("Entry No.", ConvertCodeToInteger(FSNExtItemEntryTransf."Source No."));
                                        FSNExtItemEntryTransfM.SetRange(Done, false);
                                        FSNExtItemEntryTransfM.SetFilter(Quantity, '>%1', 0); // Buscar entrada
                                        if FSNExtItemEntryTransfM.FindFirst() then begin
                                            // Existe una entrada, si este es salida, marcar con error
                                            if FSNExtItemEntryTransf.Quantity < 0 then begin
                                                FSNExtItemEntryTransf."Apply Entry" := true;
                                                FSNExtItemEntryTransf."Last error" := StrSubstNo(Text015, FSNExtItemEntryTransfM."Entry No.");
                                                FSNExtItemEntryTransf.Done := true;
                                                FSNExtItemEntryTrMOD := FSNExtItemEntryTransf;
                                                FSNExtItemEntryTrMOD.Modify(true);
                                            end;
                                        end;
                                    until FSNExtItemEntryTransf.Next() = 0;
                                end;

                                if FSNExternalItemEntry.Find('-') then begin
                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, FSNExternalItemEntry.Count(), false);
                                    repeat
                                        if (FSNExternalItemEntry.Subinventoy = 'ALMACENAJE') and (FSNExternalItemEntry."Transfer Subinventory" = 'PICKING') then begin
                                            FSNExternalItemEntry."Apply Entry" := false;
                                            FSNExternalItemEntry."Last error" := StrSubstNo(Text013, 'ALMACENAJE', 'PICKING');//16012000
                                            FSNExternalItemEntry.Done := true;
                                            FSNExternalItemEntry.Modify();
                                            FSNExternalItemEntryTransf.Reset();
                                            FSNExternalItemEntryTransf.SetFilter("Entry No.", '%1', ConvertCodeToInteger(FSNExternalItemEntry."Source No."));
                                            if FSNExternalItemEntryTransf.FindFirst() then begin
                                                FSNExternalItemEntryTransf."Apply Entry" := false;
                                                FSNExternalItemEntryTransf."Last error" := StrSubstNo(Text013, 'PICKING', 'ALMACENAJE');
                                                FSNExternalItemEntryTransf.Done := true;
                                                FSNExternalItemEntryTransf.Modify();
                                            end;
                                        end;
                                        ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, false);
                                        CountEntry += 1;
                                    until FSNExternalItemEntry.Next() = 0;
                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, true);
                                end;
                                if FSNExternalItemEntry.Find('-') then begin
                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, FSNExternalItemEntry.Count(), false);
                                    repeat
                                        if (FSNExternalItemEntry.Subinventoy = 'PICKING') and (FSNExternalItemEntry."Transfer Subinventory" = 'ALMACENAJE') then begin
                                            FSNExternalItemEntry."Apply Entry" := false;
                                            FSNExternalItemEntry."Last error" := StrSubstNo(Text013, 'PICKING', 'ALMACENAJE');
                                            FSNExternalItemEntry.Done := true;
                                            FSNExternalItemEntry.Modify();
                                            FSNExternalItemEntryTransf.Reset();
                                            FSNExternalItemEntryTransf.SetFilter("Entry No.", '%1', ConvertCodeToInteger(FSNExternalItemEntry."Source No."));
                                            if FSNExternalItemEntryTransf.FindFirst() then begin
                                                FSNExternalItemEntryTransf."Apply Entry" := false;
                                                FSNExternalItemEntryTransf."Last error" := StrSubstNo(Text013, 'ALMACENAJE', 'PICKING');
                                                FSNExternalItemEntryTransf.Done := true;
                                                FSNExternalItemEntryTransf.Modify();
                                            end;
                                        end;
                                        ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, false);
                                        CountEntry += 1;
                                    until FSNExternalItemEntry.Next() = 0;


                                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, 0, true);
                                end;
                            end;
                    end;
                end;

                FSNExternalItemEntry.SetAscending("Posting Date", true);
                FSNExternalItemEntry.SetAscending(Subinventoy, true);
                FSNExternalItemEntry.SetAscending("Document No.", true);
                FSNExternalItemEntry.SetAscending("Order Line No.", true);
                //agregar filtro por No. Documento si viene en parametros
                FSNExternalItemEntry.SetRange("Last error", '');
                if FSNExternalItemEntry.Find('-') then begin
                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountDocumentLine, TotalDocumentLine, false);
                    repeat
                        ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountDocumentLine, TotalDocumentLine, false);
                        FSNExternalItemEntry."Journal Template Name" := ItemJnlTemplate."Name";
                        FSNExternalItemEntry."Journal Batch Name" := ItemJnlBatch."Name";
                        FSNExternalItemEntry."Apply Entry" := false;
                        FSNExternalItemEntry."Last error" := '';
                        breakExternalEntry := false;
                        QtyBase := 0;
                        Item.Reset();
                        ItemUMP.Reset();

                        case DocumentType of
                            DocumentType::"Purchase Receipt":
                                begin
                                    if PrevDocumentNo <> FSNExternalItemEntry."Document No." then begin
                                        CountDocumentLine := 0;
                                        TotalDocumentLine := 0;
                                        ApplyFullDocument := true;
                                        CountExterItemEntryByDocument.Reset();
                                        CountExterItemEntryByDocument.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                        CountExterItemEntryByDocument.SetRange("Document No.", FSNExternalItemEntry."Document No.");
                                        CountExterItemEntryByDocument.SetRange(Done, false);
                                        CountExterItemEntryByDocument.SetFilter(Quantity, '<>%1', 0);
                                        TotalDocumentLine := CountExterItemEntryByDocument.Count();
                                    end;
                                end;
                            DocumentType::"Purchase Return Shipment":
                                begin
                                    if FSNExternalItemEntry.Origin <> '' then
                                        if PrevSubinventoy <> FSNExternalItemEntry.Subinventoy then begin
                                            CountDocumentLine := 0;
                                            TotalDocumentLine := 0;
                                            ApplyFullDocument := true;
                                            CountExterItemEntryByDocument.Reset();
                                            CountExterItemEntryByDocument.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                            CountExterItemEntryByDocument.SetRange(Subinventoy, FSNExternalItemEntry.Subinventoy);
                                            CountExterItemEntryByDocument.SetRange("Source No.", FSNExternalItemEntry."Source No.");
                                            CountExterItemEntryByDocument.SetRange(Done, false);
                                            CountExterItemEntryByDocument.SetFilter(Quantity, '<>%1', 0);
                                            TotalDocumentLine := CountExterItemEntryByDocument.Count();
                                            if FSNExternalItemEntry."Source No." = '' then begin
                                                PurchaseConf.Get();
                                                PrevDocumentNo := NoSeriesMgt.GetNextNo(PurchaseConf."Return Order Nos.", Today, false);
                                            end;
                                        end;
                                    if FSNExternalItemEntry."Source No." = '' then
                                        FSNExternalItemEntry."Source No." := PrevDocumentNo;

                                end;
                            DocumentType::" ":
                                begin
                                    if FSNExternalItemEntry.Quantity > 0 then
                                        EntryType := EntryType::"Positive Adjmt."
                                    else
                                        EntryType := EntryType::"Negative Adjmt.";

                                    if PrevPostingDate <> FSNExternalItemEntry."Posting Date" then begin
                                        CountDocumentLine := 0;
                                        TotalDocumentLine := 0;
                                        ApplyFullDocument := true;
                                        CountExterItemEntryByDocument.Reset();
                                        CountExterItemEntryByDocument.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                        CountExterItemEntryByDocument.SetRange("Posting Date", FSNExternalItemEntry."Posting Date");
                                        CountExterItemEntryByDocument.SetRange(Done, false);
                                        CountExterItemEntryByDocument.SetFilter(Quantity, '<>%1', 0);
                                        TotalDocumentLine := CountExterItemEntryByDocument.Count();
                                        if FSNExternalItemEntry."Source No." = '' then
                                            PrevDocumentNo := NoSeriesMgt.GetNextNo(ItemJnlBatch."No. Series", FSNExternalItemEntry."Posting Date", false);
                                    end;
                                    if FSNExternalItemEntry."Source No." = '' then
                                        FSNExternalItemEntry."Source No." := PrevDocumentNo;

                                end;
                            DocumentType::"Direct Transfer":
                                begin
                                    if PrevDocumentNo <> FSNExternalItemEntry."Source No." then begin
                                        CountDocumentLine := 0;
                                        TotalDocumentLine := 0;
                                        ApplyFullDocument := true;
                                        CountExterItemEntryByDocument.Reset();
                                        CountExterItemEntryByDocument.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                        CountExterItemEntryByDocument.SetRange("Source No.", FSNExternalItemEntry."Source No.");
                                        CountExterItemEntryByDocument.SetRange(Done, false);
                                        CountExterItemEntryByDocument.SetFilter(Quantity, '<>%1', 0);
                                        TotalDocumentLine := CountExterItemEntryByDocument.Count();
                                        ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountDocumentLine, TotalDocumentLine, false);
                                    end;
                                end;
                        end;

                        if ApplyFullDocument or (not breakExternalEntry) then begin

                            //if CheckEmptyLocationCode(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry) then
                            if not CheckEmptySubInventory(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry) then
                                if not CheckExistItem(Item, FSNExternalItemEntry, breakExternalEntry) then
                                    if not CheckConvertQtyUOMBase(Item, ItemUMP, FSNExternalItemEntry, QtyBase, breakExternalEntry) then
                                        if not CheckItemLedgerEntryNo(EntryType, DocumentType, Item, FSNExternalItemEntry, FSNExternalCatLocation."BC Location Code", QtyBase, breakExternalEntry) then
                                            if not CheckLotNoEmpty(FSNExternalItemEntry, Item, breakExternalEntry) then
                                                FSNExternalItemEntry."Apply Entry" := true;

                            if not breakExternalEntry then
                                if EntryType = EntryType::Transfer then begin
                                    if not CheckEmptySourceNo(FSNExternalItemEntry, breakExternalEntry) then
                                        //if not CheckEmptySubInventory(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry) then
                                        if not CheckEmptyTransferSubInventory(FSNExternalItemEntry, FSNExternalCatLocationTo, breakExternalEntry) then
                                            CheckTransferInventory(FSNExternalItemEntry, Item, QtyBase, FSNExternalCatLocation, breakExternalEntry);

                                    if breakExternalEntry then
                                        FSNExternalItemEntry."Apply Entry" := false;
                                end;
                            if not breakExternalEntry then
                                case EntryType of
                                    EntryType::"Negative Adjmt.", EntryType::"Positive Adjmt.":
                                        begin
                                            InsertItemJrnlLn(EntryType, DocumentType, FSNExternalItemEntry, FSNExternalCatLocation, FSNExternalCatLocationTo, Item, ItemUMP, QtyBase, ItemJnlBatch, breakExternalEntry);
                                        end;
                                    EntryType::Transfer:
                                        begin
                                            InsertItemJrnlLn(EntryType, DocumentType, FSNExternalItemEntry, FSNExternalCatLocation, FSNExternalCatLocationTo, Item, ItemUMP, QtyBase, ItemJnlBatch, breakExternalEntry);
                                        end;
                                    EntryType::Purchase:
                                        case DocumentType of
                                            DocumentType::"Purchase Return Shipment":
                                                begin
                                                    if FSNExternalItemEntry.Origin <> '' then begin
                                                        if PrevDocumentNo <> FSNExternalItemEntry.Subinventoy then
                                                            InsertPurchaseHeader(PurchHdr, FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry);
                                                        if not breakExternalEntry then begin
                                                            FSNExternalItemEntry."Journal Batch Name" := PurchHdr."No.";
                                                            InsertPurchLine(EntryType, DocumentType, FSNExternalItemEntry, PurchHdr, FSNExternalCatLocation, Item, ItemUMP, QtyBase, breakExternalEntry);
                                                        end;
                                                    end;
                                                end;
                                            DocumentType::"Purchase Receipt":
                                                begin
                                                    if PrevDocumentNo <> FSNExternalItemEntry."Document No." then begin
                                                        Clear(ItemExternalLines);
                                                        Clear(ItemQtyExternalLines);
                                                        PostFSNExternalItemEntry.Reset();
                                                        PostFSNExternalItemEntry.Copy(FSNExternalItemEntry);
                                                    end;
                                                    if not ItemExternalLines.ContainsKey(Item."No.") then begin
                                                        ItemExternalLines.Add(Item."No.", FSNExternalItemEntry."Item No.");
                                                        ItemQtyExternalLines.Add(Item."No.", QtyBase);
                                                    end else begin
                                                        ItemQtyExternalLines.Set(Item."No.", ItemQtyExternalLines.Get(Item."No.") + QtyBase);
                                                    end;
                                                end;
                                        end;
                                end;
                        end;
                        if PrevDocumentNo <> FSNExternalItemEntry."Source No." then
                            CountDocumentLine := 1
                        else
                            CountDocumentLine += 1;

                        if (not FSNExternalItemEntry."Apply Entry") and (DocumentType <> DocumentType::"Purchase Receipt") and (DocumentType <> DocumentType::"Direct Transfer") then
                            ApplyFullDocument := false;

                        FSNExternalItemEntry.Modify();

                        if PostAutomatically then begin
                            case EntryType of
                                EntryType::"Negative Adjmt.", EntryType::"Positive Adjmt.":
                                    begin
                                        if (CountDocumentLine = TotalDocumentLine) and ApplyFullDocument then
                                            PostJrnlByDocumentNo(EntryType, FSNExternalItemEntry, breakExternalEntry)
                                        else begin
                                            DeleteReservationEntryByTemplateBatch(ItemJnlTemplate."Name", ItemJnlBatch."Name");
                                            DeleteItemJrnlLineByTemplateBatch(ItemJnlTemplate."Name", ItemJnlBatch."Name", DocumentNo);
                                        end;
                                    end;
                                EntryType::Transfer:
                                    begin
                                        if (CountDocumentLine = TotalDocumentLine) and ApplyFullDocument then
                                            PostJrnlByDocumentNo(EntryType, FSNExternalItemEntry, breakExternalEntry)
                                    end;
                                EntryType::Purchase:
                                    case DocumentType of
                                        DocumentType::"Purchase Return Shipment":
                                            begin
                                                if (CountDocumentLine = TotalDocumentLine) and ApplyFullDocument then
                                                    CODEUNIT.RUN(CODEUNIT::"Purch.-Post", PurchHdr);

                                                if (CountDocumentLine = TotalDocumentLine) and (not ApplyFullDocument) then
                                                    if PurchHdr.Delete() then;
                                            end;
                                        DocumentType::"Purchase Receipt":
                                            begin
                                                if (CountDocumentLine = TotalDocumentLine) then begin
                                                    PurchOrderReceiving(EntryType, DocumentType, PostFSNExternalItemEntry, ItemExternalLines, ItemQtyExternalLines, FSNExternalCatLocation, breakExternalEntry);
                                                end;
                                            end;
                                    end;

                            end;

                        end;
                        case DocumentType of
                            DocumentType::"Purchase Return Shipment", DocumentType::"Direct Transfer":
                                begin
                                    PrevSubinventoy := FSNExternalItemEntry.Subinventoy;
                                    PrevDocumentNo := FSNExternalItemEntry."Source No.";
                                end;
                            DocumentType::"Purchase Receipt":
                                begin
                                    PrevDocumentNo := FSNExternalItemEntry."Document No.";
                                end;
                            DocumentType::" ":
                                begin
                                    if EntryType in [EntryType::"Positive Adjmt.", EntryType::"Negative Adjmt."] then begin
                                        PrevDocumentNo := FSNExternalItemEntry."Source No.";
                                        PrevPostingDate := FSNExternalItemEntry."Posting Date";
                                    end;
                                end;
                        end;
                        CountEntry += 1;
                        Commit();
                    until FSNExternalItemEntry.Next() = 0;
                    ShowProcessDialog(ShowDialog, WindowIsOpen, Progress, CountEntry, TotalDocumentLine, true);
                end;
            until FSNExternalCatalog.Next() = 0;
        end;
        if WindowIsOpen then
            Progress.Close();
    end;

    local procedure ShowProcessDialog(
        var ShowDialog: Boolean;
        var WindowIsOpen: Boolean;
        var Progress: Dialog;
        var CountEntry: Integer;
        CountTotalEntry: Integer;
        ShowDialogClose: Boolean)
    var
        ProgressMsgL: Label 'Procesando: #1 de #2 ###############';
    begin
        if ShowDialogClose then
            if WindowIsOpen then begin
                Progress.Close();
                WindowIsOpen := false;
                Exit;
            end;
        if ShowDialog then begin
            if not WindowIsOpen then begin
                CountEntry := 0;
                Progress.Open(ProgressMsgL);
                Progress.Update(1, CountEntry);
                Progress.Update(2, CountTotalEntry);
                WindowIsOpen := true;
            end else begin
                Progress.Update(1, CountEntry);
                if CountTotalEntry <> 0 then
                    Progress.Update(2, CountTotalEntry);
            end;
        end else
            if WindowIsOpen then
                Progress.Close();
    end;

    local procedure InsertItemJrnlLn(
        EntryType: Enum "Item Ledger Entry Type";
        DocumentType: Enum "Item Ledger Document Type";
        var FSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalCatLocation: Record "FSN External Catalog";
        FSNExternalCatLocationTo: Record "FSN External Catalog";
        Item: Record Item;
        ItemUMP: Record "Item Unit of Measure";
        QtyBase: Decimal;
        ItemJnlBatch: Record "Item Journal Batch";
        var breakExternalEntry: Boolean)
    var
        ItemJnlLn: Record "Item Journal Line";
    begin
        ItemJnlLn.Init();
        ItemJnlLn."Journal Template Name" := FSNExternalItemEntry."Journal Template Name";
        ItemJnlLn."Journal Batch Name" := FSNExternalItemEntry."Journal Batch Name";
        ItemJnlLn."Source Code" := ItemJnlBatch."Reason Code";
        ItemJnlLn."Entry Type" := EntryType;
        ItemJnlLn."Document Type" := DocumentType;
        ItemJnlLn."Posting Date" := FSNExternalItemEntry."Posting Date";
        ItemJnlLn."Document Date" := FSNExternalItemEntry."Document Date";
        ItemJnlLn."Line No." := GetNextLineNo(FSNExternalItemEntry."Journal Template Name", FSNExternalItemEntry."Journal Batch Name", EntryType, DocumentType, FSNExternalItemEntry."Document No.");
        ItemJnlLn."Document No." := Format(FSNExternalItemEntry."Entry No.");
        ItemJnlLn.Validate("Item No.", Item."No.");
        ItemJnlLn.Validate("Unit of Measure Code", Item."Base Unit of Measure");
        ItemJnlLn."Location Code" := FSNExternalCatLocation."BC Location Code";

        if DocumentType = DocumentType::"Direct Transfer" then begin
            IF FSNExternalItemEntry.Quantity > 0 THEN begin
                ItemJnlLn."Location Code" := FSNExternalCatLocationTo."BC Location Code";
                ItemJnlLn."New Location Code" := FSNExternalCatLocation."BC Location Code";
            end ELSE BEGIN
                ItemJnlLn."Location Code" := FSNExternalCatLocation."BC Location Code";
                ItemJnlLn."New Location Code" := FSNExternalCatLocationTo."BC Location Code";
            END;
        end;

        if Item."Item Tracking Code" <> '' then begin
            ItemJnlLn."Expiration Date" := FSNExternalItemEntry."Expiration Date";
            ItemJnlLn."Lot No." := FSNExternalItemEntry."Lot No.";
            if ItemJnlLn."Lot No." <> '' then
                CheckLotNoExitsItemLedgerEntry(ItemJnlLn, breakExternalEntry);
        end;
        ItemJnlLn.Validate(Quantity, ABS(QtyBase));
        if ItemJnlLn.Insert(true) then begin
            if Item."Item Tracking Code" <> '' then begin
                if ItemJnlLn."Lot No." <> '' then
                    if not InsertReservationEntryByLotNo(ItemJnlLn, FSNExternalItemEntry, Item, breakExternalEntry) then
                        FSNExternalItemEntry."Apply Entry" := true
            end else
                FSNExternalItemEntry."Apply Entry" := true;
        end else begin
            FSNExternalItemEntry."Last error" := Text008 + CopyStr(GetLastErrorText(), 1, 200);
            FSNExternalItemEntry."Apply Entry" := false;
        end;
    end;

    local procedure InsertPurchaseHeader(var PurchHdr: Record "Purchase Header"; var FSNExternalItemEntry: Record "FSN External Item Entry"; FSNExternalCatLocation: Record "FSN External Catalog"; var breakExternalEntry: Boolean)
    var
        Vendor: Record Vendor;
    begin
        Commit();
        Vendor.Reset();
        Vendor.SetRange("Name 2", FSNExternalItemEntry.Origin);
        if Vendor.FindFirst() then;
        PurchHdr.Reset();
        Clear(PurchHdr);
        PurchHdr.Init();
        PurchHdr."Document Type" := PurchHdr."Document Type"::"Return Order";
        PurchHdr.Validate("Buy-from Vendor No.", Vendor."No.");
        PurchHdr.InitInsert();
        if not PurchHdr.Insert() then begin
            FSNExternalItemEntry."Apply Entry" := false;
            FSNExternalItemEntry."Last error" := GetLastErrorText();
            breakExternalEntry := true;
        end;
        PurchHdr.Validate("Location Code", FSNExternalCatLocation."BC Location Code");
        PurchHdr."Vendor Authorization No." := CopyStr(PurchHdr."No.", 4, 20);
        PurchHdr.Ship := True;
        PurchHdr.Receive := false;
        PurchHdr.Invoice := false;
        PurchHdr.Modify();
    end;

    local procedure InsertPurchLine(
        EntryType: Enum "Item Ledger Entry Type";
        DocumentType: Enum "Item Ledger Document Type";
        var FSNExternalItemEntry: Record "FSN External Item Entry";
        var PurchHdr: Record "Purchase Header";
        FSNExternalCatLocation: Record "FSN External Catalog";
        Item: Record Item;
        ItemUMP: Record "Item Unit of Measure";
        QtyBase: Decimal;
        var breakExternalEntry: Boolean
    )
    var
        PurchLn: Record "Purchase Line";
    begin
        PurchLn.Reset();
        PurchLn.SetRange("Document Type", PurchLn."Document Type"::"Return Order");
        PurchLn.SetRange("Document No.", PurchHdr."No.");
        purchLn.SetRange("Type", PurchLn.Type::Item);
        PurchLn.SetRange("No.", Item."No.");
        if PurchLn.FindFirst() then begin
            PurchLn.Validate(Quantity, Abs(QtyBase) + PurchLn.Quantity);
            PurchLn.Validate("Return Qty. to Ship", Abs(QtyBase) + PurchLn."Return Qty. to Ship");
            PurchLn.Modify(true);
        end else begin
            PurchLn.Init();
            PurchLn."Document No." := PurchHdr."No.";
            PurchLn."Line No." := GetNextLineNo(FSNExternalItemEntry."Journal Template Name", FSNExternalItemEntry."Journal Batch Name", EntryType, DocumentType, PurchHdr."No.");
            PurchLn.Validate("Document Type", PurchLn."Document Type"::"Return Order");
            PurchLn.Validate("Type", PurchLn.Type::Item);
            PurchLn.Validate("No.", Item."No.");
            PurchLn.Validate("Unit of Measure", Item."Base Unit of Measure");
            PurchLn.Validate(Quantity, Abs(QtyBase));
            PurchLn.Validate("Return Qty. to Ship", Abs(QtyBase));
            if PurchLn.Insert(true) then
                FSNExternalItemEntry."Apply Entry" := true
            else begin
                FSNExternalItemEntry."Apply Entry" := false;
                FSNExternalItemEntry."Last error" := ''; //Clasificar error
                breakExternalEntry := true;
            end;
        end;
    end;

    local procedure CheckJrnlTemplateAndClearItemJrnl(var ItemJnlTemplate: Record "Item Journal Template"; var ItemJnlBatch: Record "Item Journal Batch"; var ItemJnlLn: Record "Item Journal Line"; TemplateName: Code[20]; BatchName: Code[20])
    var

    begin
        //Validate Item Journal Template and Batch
        if not ItemJnlTemplate.Get(TemplateName) then
            Error(Text006, TemplateName)
        else
            //Validate Item Journal Batch
            if not ItemJnlBatch.Get(ItemJnlTemplate.Name, BatchName) then
                Error(Text007, BatchName);
        //Delete all lines in the reservation entry
        DeleteReservationEntryByTemplateBatch(ItemJnlTemplate."Name", ItemJnlBatch."Name");
        //Delete all lines in the Item Journal Batch
        ItemJnlLn.SetRange("Journal Template Name", ItemJnlTemplate."Name");
        ItemJnlLn.SetRange("Journal Batch Name", ItemJnlBatch."Name");
        if ItemJnlLn.FindFirst() then begin
            ItemJnlLn.DeleteAll(true);
        end;

    end;

    local procedure CheckExistItem(var Item: Record Item; var FSNExternalItemEntry: Record "FSN External Item Entry"; var breakExternalEntry: Boolean): Boolean
    var
        FSNWMSLevels: Record "FSN WMS Levels";
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        FSNWMSLevels.Reset();
        FSNWMSLevels.SetFilter(CodeBar, '%1', FSNExternalItemEntry."Item No.");
        if FSNWMSLevels.FindFirst() then begin
            if not Item.Get(FSNWMSLevels.ItemNo) then begin
                FSNExternalItemEntry."Last error" := StrSubstNo(Text012, Item.FieldName("No."), Item.TableName, FSNWMSLevels.FieldName(ItemNo), FSNWMSLevels.ItemNo);
                FSNExternalItemEntry."Apply Entry" := false;
                breakExternalEntry := true;
            end;
        end else begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text012, FSNWMSLevels.FieldName(CodeBar), FSNWMSLevels.TableName, FSNExternalItemEntry.FieldName("Item No."), FSNExternalItemEntry."Item No.");
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckConvertQtyUOMBase(var Item: Record Item; var ItemUMP: Record "Item Unit of Measure"; var FSNExternalItemEntry: Record "FSN External Item Entry"; var QtyBase: Decimal; var breakExternalEntry: Boolean): Boolean
    var
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if ItemUMP.Get(Item."No.", Item."Purch. Unit of Measure") then begin
            QtyBase := FSNExternalItemEntry.Quantity;//* ItemUMP."Qty. per Unit of Measure";
        end else begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text012, ItemUMP.FieldName("Item No."), ItemUMP.TableName, Item.FieldName("Purch. Unit of Measure"), Item."Purch. Unit of Measure");
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckEmptyLocationCode(var FSNExternalItemEntry: Record "FSN External Item Entry"; var FSNExternalCatLocation: Record "FSN External Catalog"; var breakExternalEntry: Boolean): Boolean
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if FSNExternalItemEntry."Location Code" = '' then begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text011, FSNExternalItemEntry.FieldName("Location Code"));
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end else begin
            //Validate that Location Code exists in FSN External Catalog
            FSNExternalCatLocation.Reset();
            FSNExternalCatLocation.SetRange("Catalog Name", FSNExternalCatLocation."Catalog Name"::"Location Code");
            FSNExternalCatLocation.SetRange("EBS Value", FSNExternalItemEntry."Location Code");
            if not FSNExternalCatLocation.FindFirst() then begin
                FSNExternalItemEntry."Last error" := StrSubstNo(Text012, FSNExternalCatLocation.FieldName("EBS Value"), FSNExternalCatLocation.TableName, FSNExternalItemEntry.FieldName("Location Code"), FSNExternalItemEntry."Location Code");
                FSNExternalItemEntry."Apply Entry" := false;
                breakExternalEntry := true;
            end;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckEmptySubInventory(var FSNExternalItemEntry: Record "FSN External Item Entry"; var FSNExternalCatLocation: Record "FSN External Catalog"; var breakExternalEntry: Boolean): Boolean
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if FSNExternalItemEntry.Subinventoy = '' then begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text011, FSNExternalItemEntry.FieldName(Subinventoy));
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end else begin
            //Validate that SubInventary exists in FSN External Catalog
            FSNExternalCatLocation.Reset();
            FSNExternalCatLocation.SetRange("Catalog Name", FSNExternalCatLocation."Catalog Name"::"Location Code");
            FSNExternalCatLocation.SetRange("EBS Value", FSNExternalItemEntry.Subinventoy);
            if not FSNExternalCatLocation.FindFirst() then begin
                FSNExternalItemEntry."Last error" := StrSubstNo(Text012, FSNExternalCatLocation.FieldName("EBS Value"), FSNExternalCatLocation.TableName, FSNExternalItemEntry.FieldName(Subinventoy), FSNExternalItemEntry.Subinventoy);
                FSNExternalItemEntry."Apply Entry" := false;
                breakExternalEntry := true;
            end;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckEmptyTransferSubInventory(var FSNExternalItemEntry: Record "FSN External Item Entry"; var FSNExternalCatLocationTo: Record "FSN External Catalog"; var breakExternalEntry: Boolean): Boolean
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if FSNExternalItemEntry."Transfer Subinventory" = '' then begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text011, FSNExternalItemEntry.FieldName("Transfer Subinventory"));
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end else begin
            //Validate that SubInventary exists in FSN External Catalog
            FSNExternalCatLocationTo.Reset();
            FSNExternalCatLocationTo.SetRange("Catalog Name", FSNExternalCatLocationTo."Catalog Name"::"Location Code");
            FSNExternalCatLocationTo.SetRange("EBS Value", FSNExternalItemEntry."Transfer Subinventory");
            if not FSNExternalCatLocationTo.FindFirst() then begin
                FSNExternalItemEntry."Last error" := StrSubstNo(Text012, FSNExternalCatLocationTo.FieldName("EBS Value"), FSNExternalCatLocationTo.TableName, FSNExternalItemEntry.FieldName("Transfer Subinventory"), FSNExternalItemEntry."Transfer Subinventory");
                FSNExternalItemEntry."Apply Entry" := false;
                breakExternalEntry := true;
            end;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckEmptySourceNo(var FSNExternalItemEntry: Record "FSN External Item Entry"; var breakExternalEntry: Boolean): Boolean
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        //Validar que la Source code sea diferente de vacio 
        if FSNExternalItemEntry."Source No." = '' then begin
            FSNExternalItemEntry."Last error" := StrSubstNo(Text011, FSNExternalItemEntry.FieldName("Source No."));
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end;
        exit(breakExternalEntry);
    end;

    local procedure CheckLotNoExitsItemLedgerEntry(var ItemJnlLn: record "Item Journal Line"; var breakExternalEntry: Boolean)
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        ItemLedgEntryNo: Text[150];
    begin
        ItemLedgEntry.Reset();
        ItemLedgEntry.SetCurrentKey("Entry Type", "Location Code", "Posting Date");
        ItemLedgEntry.SetRange("Entry Type", ItemJnlLn."Entry Type");
        ItemLedgEntry.SetRange("Location Code", ItemJnlLn."Location Code");
        ItemLedgEntry.SetRange("Item No.", ItemJnlLn."Item No.");
        ItemLedgEntry.SetRange("Lot No.", ItemJnlLn."Lot No.");
        ItemLedgEntry.SetAscending("Posting Date", true);
        if ItemLedgEntry.FindFirst() then
            ItemJnlLn."Expiration Date" := ItemLedgEntry."Expiration Date";
    end;

    local procedure CheckItemLedgerEntryNo(EntryType: Enum "Item Ledger Entry Type"; DocumentType: Enum "Item Ledger Document Type"; var Item: Record "Item"; var FSNExternalItemEntry: Record "FSN External Item Entry"; LocationCode: Code[10]; QuantityBase: Decimal; var breakExternalEntry: Boolean): Boolean
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        PurchRcptLn: Record "Purch. Rcpt. Line";
        FsnExtSearch: Record "FSN External Item Entry";
        Qty: Decimal;
        ItemLedgEntryNo: Text[150];
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        Qty := ABS(QuantityBase);
        ItemLedgEntry.Reset();
        ItemLedgEntry.SetRange("Entry Type", EntryType);
        ItemLedgEntry.SetRange("Document Type", DocumentType);
        ItemLedgEntry.SetRange("Location Code", LocationCode);
        if EntryType IN [ItemLedgEntry."Entry Type"::Purchase] then begin
            PurchRcptLn.Reset();
            PurchRcptLn.SetRange("Order No.", FSNExternalItemEntry."Source No.");
            PurchRcptLn.SetRange("No.", Item."No.");
            PurchRcptLn.SetFilter(Quantity, '<>%1', 0);
            if PurchRcptLn.Find('-') then begin
                repeat
                    if PurchRcptLn.Quantity = FSNExternalItemEntry.Quantity then begin
                        ItemLedgEntry.SetRange("Document No.", PurchRcptLn."Document No.");
                        Qty := FSNExternalItemEntry.Quantity;
                        ItemLedgEntry.SetFilter(Quantity, '%1', Qty);
                        if not ItemLedgEntry.FindFirst() then begin
                            Qty := QuantityBase;
                        end;
                    end else begin
                        FsnExtSearch.Reset();
                        FsnExtSearch.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
                        FsnExtSearch.SetRange("Document No.", FSNExternalItemEntry."Document No.");
                        FsnExtSearch.SetRange("Source No.", FSNExternalItemEntry."Source No.");
                        FsnExtSearch.SetRange("Item No.", FSNExternalItemEntry."Item No.");
                        if FsnExtSearch.FindSet() then begin
                            FsnExtSearch.CalcSums(Quantity);
                            if PurchRcptLn.Quantity = FsnExtSearch.Quantity then begin
                                ItemLedgEntry.SetRange("Document No.", PurchRcptLn."Document No.");
                                Qty := FsnExtSearch.Quantity;
                            end;
                        end;
                    end;
                until PurchRcptLn.Next() = 0;
                ItemLedgEntry.SetFilter(Quantity, '%1', Qty);
                if not ItemLedgEntry.FindFirst() then begin
                    Qty := QuantityBase;
                end;
            end else
                ItemLedgEntry.SetRange("Document No.", FSNExternalItemEntry."Source No.");
        end else
            if EntryType = ItemLedgEntry."Entry Type"::Transfer then
                ItemLedgEntry.SetRange("Document No.", Format(FSNExternalItemEntry."Entry No."))
            else
                ItemLedgEntry.SetRange("Document No.", FSNExternalItemEntry."Source No.");

        ItemLedgEntry.SetRange("Item No.", Item."No.");
        if EntryType IN [ItemLedgEntry."Entry Type"::Purchase, ItemLedgEntry."Entry Type"::"Positive Adjmt."] then
            ItemLedgEntry.SetFilter(Quantity, '%1', Qty)
        else
            ItemLedgEntry.SetFilter(Quantity, '%1', Qty * -1);

        if ItemLedgEntry.FindFirst() then begin
            if FSNExternalItemEntry."No. Mov. BC" = 0 then begin
                FSNExternalItemEntry."No. Mov. BC" := ItemLedgEntry."Entry No.";
                FSNExternalItemEntry.Date := WorkDate;
            end;
            FSNExternalItemEntry."Last error" := '';
            if (FSNExternalItemEntry."No. Mov. BC" <> ItemLedgEntry."Entry No.") then
                FSNExternalItemEntry."Last error" := StrSubstNo(Text009, FSNExternalItemEntry.FieldName("No. Mov. BC"), FSNExternalItemEntry."No. Mov. BC", ItemLedgEntry.TableName, ItemLedgEntry.FieldName("Entry No."), ItemLedgEntry."Entry No.");
            if ItemLedgEntry.Count > 1 then begin
                repeat
                    ItemLedgEntryNo += FORMAT(ItemLedgEntry."Entry No.") + ', ';
                until ItemLedgEntry.Next() = 0;
                ItemLedgEntryNo := CopyStr(CopyStr(ItemLedgEntryNo, 1, StrLen(ItemLedgEntryNo) - 2), 1, 200);
                FSNExternalItemEntry."Last error" := StrSubstNo(Text010, FSNExternalItemEntry.FieldName("Entry No."), FSNExternalItemEntry."Entry No.", ItemLedgEntryNo);
            end;
            FSNExternalItemEntry.Done := true;
            if EntryType = ItemLedgEntry."Entry Type"::Transfer then
                FSNExternalItemEntry."Apply Entry" := true
            ELSE
                FSNExternalItemEntry."Apply Entry" := false;

            breakExternalEntry := true;
        end else
            FSNExternalItemEntry."No. Mov. BC" := 0;
        exit(breakExternalEntry);
    end;

    local procedure GetNextLineNo(JournalTemplateName: Code[20]; JournalBatchName: Code[20]; EntryType: Enum "Item Ledger Entry Type"; DocumentType: Enum "Item Ledger Document Type"; DocumentNo: Code[20]) NextLineNo: Integer
    var
        ItemJournalLine: Record "Item Journal Line";
        PurchLine: Record "Purchase Line";
    begin
        NextLineNo := 0;
        case EntryType of
            EntryType::"Positive Adjmt.", EntryType::"Negative Adjmt.", EntryType::Transfer:
                begin
                    ItemJournalLine.Reset();
                    ItemJournalLine.SetRange("Journal Template Name", JournalTemplateName);


                    ItemJournalLine.SetRange("Journal Batch Name", JournalBatchName);
                    ItemJournalLine.SetAscending("Line No.", true);
                    if ItemJournalLine.FindLast() then
                        NextLineNo := ItemJournalLine."Line No.";
                end;
            EntryType::"Purchase":
                begin
                    case DocumentType of
                        DocumentType::"Purchase Return Shipment":
                            begin
                                PurchLine.Reset();
                                PurchLine.SetRange("Document Type", PurchLine."Document Type"::"Return Order");
                                PurchLine.SetRange("Document No.", DocumentNo);
                                PurchLine.SetAscending("Line No.", true);
                                if PurchLine.FindLast() then
                                    NextLineNo := PurchLine."Line No.";
                            end;
                    end;
                end;
        end;
        NextLineNo += 10000; // Incremento estándar
    end;

    local procedure CheckLotNoEmpty(var FSNExternalItemEntry: Record "FSN External Item Entry"; var Item: Record Item; var breakExternalEntry: Boolean): Boolean
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if Item."Item Tracking Code" <> '' then
            if FSNExternalItemEntry."Lot No." <> '' then
                if FSNExternalItemEntry."Expiration Date" = 0D then begin
                    FSNExternalItemEntry."Last error" := StrSubstNo(Text011, FSNExternalItemEntry.FieldName("Expiration Date"));
                    FSNExternalItemEntry."Apply Entry" := false;
                    breakExternalEntry := true;
                end else
                    CheckItemTracking(FSNExternalItemEntry, Item, breakExternalEntry);
        exit(breakExternalEntry);
    end;

    local procedure CheckItemTracking(var FSNExternalItemEntry: Record "FSN External Item Entry"; var Item: Record Item; var breakExternalEntry: Boolean): Boolean
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);
        if Item."Item Tracking Code" = '' then begin
            breakExternalEntry := true;
            FSNExternalItemEntry."Apply Entry" := false;
            FSNExternalItemEntry."Last error" := StrSubstNo(Text014, Item.FieldName("No."), Item."No.", Item.TableName, Item.FieldName("Item Tracking Code"));
        end else
            if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
                breakExternalEntry := true;
                FSNExternalItemEntry."Apply Entry" := false;
                FSNExternalItemEntry."Last error" := StrSubstNo(Text014, Item.FieldName("No."), Item."No.", ItemTrackingCode.TableName, ItemTrackingCode.FieldName("Code"));
            end;
        exit(breakExternalEntry);
    end;

    local procedure CheckTransferInventory(var FSNExternalItemEntry: Record "FSN External Item Entry"; Item: Record Item; QtyBase: Decimal; FSNExternalCatLocation: Record "FSN External Catalog"; var breakExternalEntry: Boolean): Boolean
    var
        ItemLedger: Record "Item Ledger Entry";
    begin
        if breakExternalEntry then
            exit(breakExternalEntry);

        ItemLedger.Reset();
        ItemLedger.SetRange("Location Code", FSNExternalCatLocation."BC Location Code");
        ItemLedger.SetFilter("Item No.", '%1', Item."No.");
        if not ItemLedger.FindSet() then begin
            breakExternalEntry := true;
            FSNExternalItemEntry."Apply Entry" := false;
            FSNExternalItemEntry."Last error" := StrSubstNo('El producto %1 no tiene trazabilidad en el almacen %2 por lo que no se puede realizar la transferencia', Item."No.", FSNExternalCatLocation."BC Location Code");
        end;

        ItemLedger.Reset();
        ItemLedger.SetRange("Location Code", FSNExternalCatLocation."BC Location Code");
        ItemLedger.SetFilter("Item No.", '%1', Item."No.");
        ItemLedger.SetRange(Open, true);
        if ItemLedger.FindSet() then begin
            ItemLedger.CalcSums("Remaining Quantity");
            if not (ItemLedger."Remaining Quantity" >= ABS(QtyBase)) then begin
                breakExternalEntry := true;
                FSNExternalItemEntry."Apply Entry" := false;
                FSNExternalItemEntry."Last error" := StrSubstNo('Dispone de una cantidad insuficiente del producto %1 en inventario.', Item."No.");
            end;
        end else begin
            breakExternalEntry := true;
            FSNExternalItemEntry."Apply Entry" := false;
            FSNExternalItemEntry."Last error" := StrSubstNo('Dispone de una cantidad insuficiente del producto %1 en inventario.', Item."No.");
        end;
    end;

    local procedure DeleteReservationEntryByTemplateBatch(TemplateName: Code[20]; BatchName: Code[20])
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.Reset();
        ReservEntry.SetRange("Source ID", TemplateName);
        ReservEntry.SetRange("Source Batch Name", BatchName);
        if ReservEntry.FindFirst() then
            ReservEntry.DeleteAll();


    end;

    local procedure DeleteItemJrnlLineByTemplateBatch(TemplateName: Code[20]; BatchName: Code[20]; DocumentNo: Code[20])
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Journal Template Name", TemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", BatchName);
        ItemJournalLine.SetRange("Document No.", DocumentNo);
        if ItemJournalLine.FindFirst() then begin
            ItemJournalLine.DeleteAll(true);
        end;
    end;

    local procedure ConvertCodeToInteger(EntryNo: Code[20]) EntryNoI: Integer
    begin
        if EntryNo <> '' then
            Evaluate(EntryNoI, EntryNo);
    end;

    local procedure InsertReservationEntryByLotNo(var ItemJnlLn: record "Item Journal Line"; var FSNExternalItemEntry: Record "FSN External Item Entry"; var Item: Record Item; var breakExternalEntry: Boolean): Boolean
    var
        ReservEntry: Record "Reservation Entry";
    begin
        //Validate if Reservation Entry exists
        /*ReservEntry.Reset();
        ReservEntry.SetRange("Source ID", ItemJnlLn."Journal Template Name");
        ReservEntry.SetRange("Source Batch Name", ItemJnlLn."Journal Batch Name");
        ReservEntry.SetRange("Item No.", ItemJnlLn."Item No.");
        ReservEntry.SetRange("Lot No.", ItemJnlLn."Lot No.");
        ReservEntry.SetRange("Source Ref. No.", ItemJnlLn."Line No.");
        if ReservEntry.FindFirst() then
            ReservEntry.Delete();*/

        CallItemTracking(ItemJnlLn);


        ReservEntry.Init();
        ReservEntry."Source ID" := ItemJnlLn."Journal Template Name";
        ReservEntry."Source Batch Name" := ItemJnlLn."Journal Batch Name";
        ReservEntry."Location Code" := ItemJnlLn."Location Code";
        ReservEntry."Source Subtype" := ItemJnlLn."Entry Type".AsInteger();
        ReservEntry."Item No." := ItemJnlLn."Item No.";
        ReservEntry."Lot No." := ItemJnlLn."Lot No.";
        ReservEntry."New Lot No." := ItemJnlLn."Lot No.";
        ReservEntry."Expiration Date" := ItemJnlLn."Expiration Date";
        ReservEntry."New Expiration Date" := ItemJnlLn."Expiration Date";
        ReservEntry."Source Ref. No." := ItemJnlLn."Line No.";
        ReservEntry."Reservation Status" := ReservEntry."Reservation Status"::Prospect;
        ReservEntry."Item Tracking" := ReservEntry."Item Tracking"::"Lot No.";
        ReservEntry."Creation Date" := ItemJnlLn."Posting Date";
        ReservEntry."Expected Receipt Date" := ItemJnlLn."Posting Date";
        ReservEntry."Source Type" := ItemJnlLn.RecordId.TableNo;
        case ItemJnlLn."Entry Type" of
            ItemJnlLn."Entry Type"::"Positive Adjmt.":
                begin
                    ReservEntry.Positive := true;
                    ReservEntry.Quantity := ItemJnlLn.Quantity;
                    ReservEntry."Quantity (Base)" := ItemJnlLn."Quantity (Base)";
                    ReservEntry."Qty. per Unit of Measure" := ItemJnlLn."Qty. per Unit of Measure";
                    ReservEntry."Qty. to Handle (Base)" := ItemJnlLn."Quantity (Base)";
                    ReservEntry."Qty. to Invoice (Base)" := ItemJnlLn."Quantity (Base)";
                end;
            ItemJnlLn."Entry Type"::"Negative Adjmt.", ItemJnlLn."Entry Type"::Transfer:
                begin
                    ReservEntry.Positive := false;
                    ReservEntry.Quantity := -ItemJnlLn.Quantity;
                    ReservEntry."Quantity (Base)" := -ItemJnlLn."Quantity (Base)";
                    ReservEntry."Qty. per Unit of Measure" := -ItemJnlLn."Qty. per Unit of Measure";
                    ReservEntry."Qty. to Handle (Base)" := -ItemJnlLn."Quantity (Base)";
                    ReservEntry."Qty. to Invoice (Base)" := -ItemJnlLn."Quantity (Base)";
                end;
        end;
        if not ReservEntry.Insert(true) then begin
            FSNExternalItemEntry."Last error" := 'Reserva Inventario no creada: ' + CopyStr(GetLastErrorText(), 1, 200);
            FSNExternalItemEntry."Apply Entry" := false;
            breakExternalEntry := true;
        end;
    end;

    local procedure PostJrnlByDocumentNo(EntryType: Enum "Item Ledger Entry Type"; var FSNExternalItemEntry: Record "FSN External Item Entry"; var breakExternalEntry: Boolean)
    var
        ItemJnlLnPost: Record "Item Journal Line";
        ItemJnlLnPostTemp: Record "Item Journal Line" temporary;
        FsnExternalPost: Record "FSN External Item Entry";
        FsnExternalTransf: Record "FSN External Item Entry";
        Item: Record Item;
        ItemUMP: Record "Item Unit of Measure";
        QtyBase: Decimal;
    begin
        FsnExternalPost.Reset();
        FsnExternalPost.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
        FsnExternalPost.SetRange(Done, true);
        FsnExternalPost.SetRange("Source No.", FSNExternalItemEntry."Source No.");
        FsnExternalPost.SetFilter("No. Mov. BC", '<>%1', 0);
        if FsnExternalPost.FindFirst() then begin
            FsnExternalPost."Last error" := 'El Documento No. ' + FsnExternalPost."Source No." + ' ya esta procesado paracialmente por BC';
            FsnExternalPost."Apply Entry" := false;
            FsnExternalPost.Modify();
        end else begin
            FsnExternalPost.SetRange("Apply Entry", false);
            if FsnExternalPost.FindFirst() then begin
                FsnExternalPost."Last error" := 'El Documento No. ' + FsnExternalPost."Source No." + ' no se puede procesar parcialmente por BC';
                FsnExternalPost."Apply Entry" := false;
                FsnExternalPost.Modify();
            end else begin
                FsnExternalPost.SetRange("Apply Entry", true);
                FsnExternalPost.SetFilter("No. Mov. BC", '<>%1', 0);
                if FsnExternalPost.FindFirst() then begin
                    FsnExternalPost."Last error" := 'El Documento No. ' + FsnExternalPost."Source No." + ' ya esta procesado paracialmente por BC';
                    FsnExternalPost."Apply Entry" := false;
                    FsnExternalPost.Modify();
                end else begin
                    ItemJnlLnPost.Reset();
                    ItemJnlLnPost.SetRange("Journal Template Name", FSNExternalItemEntry."Journal Template Name");
                    ItemJnlLnPost.SetRange("Journal Batch Name", FSNExternalItemEntry."Journal Batch Name");
                    ItemJnlLnPost.SetRange("Entry Type", EntryType);
                    if entryType = EntryType::Transfer then
                        ItemJnlLnPost.SetRange("Document No.", format(FSNExternalItemEntry."Entry No."))
                    else
                        ItemJnlLnPost.SetRange("Document No.", FSNExternalItemEntry."Source No.");
                    ItemJnlLnPost.SetFilter("Line No.", '<>%1', 0);
                    if ItemJnlLnPost.FindFirst() then begin
                        ItemJnlLnPostTemp.Copy(ItemJnlLnPost);
                        CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post", ItemJnlLnPost);
                        FsnExternalPost.Reset();
                        FsnExternalPost.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
                        FsnExternalPost.SetRange("Source No.", FSNExternalItemEntry."Source No.");
                        FsnExternalPost.SetRange(Done, false);
                        FsnExternalPost.SetRange("Apply Entry", true);
                        if FsnExternalPost.FindFirst() then
                            repeat
                                if not CheckExistItem(Item, FsnExternalPost, breakExternalEntry) then
                                    CheckConvertQtyUOMBase(Item, ItemUMP, FsnExternalPost, QtyBase, breakExternalEntry);
                                CheckItemLedgerEntryNo(ItemJnlLnPostTemp."Entry Type", ItemJnlLnPostTemp."Document Type", Item, FsnExternalPost, ItemJnlLnPostTemp."Location Code", QtyBase, breakExternalEntry);
                                FsnExternalPost.Modify();
                            until FsnExternalPost.Next() = 0;
                        Commit();
                    end;
                end;
            end;
        end;
    end;

    procedure CallItemTracking(var ItemJnlLine: Record "Item Journal Line")
    var
        TrackingSpecification: Record "Tracking Specification" temporary;
        ReservEntry: Record "Reservation Entry";
        ItemTrackingLines: Page "Item Tracking Lines";
        IsHandled: Boolean;
    begin
        IsHandled := false;
        if IsHandled then
            exit;

        ItemJnlLine.TestField("Item No.");
        if not ItemJnlLine.ItemPosting then begin
            ReservEntry.InitSortingAndFilters(false);
            ItemJnlLine.SetReservationFilters(ReservEntry);
            ReservEntry.ClearTrackingFilter;
            if ReservEntry.IsEmpty() then
                exit;
        end;
        TrackingSpecification.init();
        TrackingSpecification.InitFromItemJnlLine(ItemJnlLine);
        TrackingSpecification.Validate("Quantity (Base)", ItemJnlLine.Quantity);
        TrackingSpecification.Validate("Location Code", ItemJnlLine."Location Code");
        TrackingSpecification.Validate("Lot No.", ItemJnlLine."Lot No.");
        if not TrackingSpecification.Insert(true) then
            error('No se pudo crear la especificación de seguimiento: %1', GetLastErrorText());

    end;


    local procedure PurchOrderReceiving(EntryType: Enum "Item Ledger Entry Type"; DocumentType: Enum "Item Ledger Document Type"; var FSNExternalItemEntry: Record "FSN External Item Entry"; var ItemExternalLines: Dictionary of [Code[20], Code[20]]; var ItemQtyExternalLines: Dictionary of [Code[20], Integer]; var FSNExternalCatalog: Record "FSN External Catalog"; var breakExternalEntry: Boolean)
    var
        PostFSNExternalItemEntry: Record "FSN External Item Entry";
        LSCPRCountingHdr: Record "LSC P/R Counting Header";
        LSCPickingReceivinglines: Record "LSC Picking / Receiving lines";
        LSCRetailReceiving: Page "LSC Retail Receiving";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        ItemLedgEntry: Record "Item Ledger Entry";
        ItemPickingLines: Dictionary of [Code[20], Integer];
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        BatchPosting: Codeunit "LSC Batch Posting";
        PRPost: Codeunit "LSC Picking/Receiving - Post";
        PurchaseHeader: Record "Purchase Header";
        Found: Boolean;
        ReceivingPartial: Integer;
        ItemNo: Code[20];
        ItemQty: Integer;
        RunOnlyOne: Boolean;
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("No.", FSNExternalItemEntry."Source No.");
        if not PurchaseHeader.FindFirst() then begin
            PostFSNExternalItemEntry.Reset();
            PostFSNExternalItemEntry.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
            PostFSNExternalItemEntry.SetRange("Source No.", FSNExternalItemEntry."Source No.");
            PostFSNExternalItemEntry.SetRange(Done, false);
            if PostFSNExternalItemEntry.Find('-') then begin
                repeat
                    PostFSNExternalItemEntry."Last error" := 'El Pedido No. ' + FSNExternalItemEntry."Source No." + ' no existe';
                    PostFSNExternalItemEntry."Apply Entry" := false;
                    PostFSNExternalItemEntry.Date := WorkDate();
                    PostFSNExternalItemEntry.Modify();
                until PostFSNExternalItemEntry.Next() = 0;
            end;
            exit;
        end;
        RunOnlyOne := false;
        LSCPRCountingHdr.Reset();
        LSCPRCountingHdr.SetRange("Reference No.", FSNExternalItemEntry."Source No.");
        LSCPRCountingHdr.SetRange("FSN Authorized Reception", true);
        if LSCPRCountingHdr.Find('-') then begin
            repeat begin
                Clear(ItemPickingLines);
                if LSCPRCountingHdr.SubTotal = LSCPRCountingHdr.ConfirmarSubTotal then begin
                    LSCPickingReceivinglines.Reset();
                    LSCPickingReceivinglines.SetRange("Document No.", LSCPRCountingHdr."No.");
                    LSCPickingReceivinglines.SetFilter(Quantity, '<>0');
                    if LSCPickingReceivinglines.FindSet() then begin
                        repeat
                            ItemPickingLines.Add(LSCPickingReceivinglines."Item No.", LSCPickingReceivinglines."Quantity (base)");
                        until LSCPickingReceivinglines.Next() = 0;
                    end;
                end;
            end until (LSCPRCountingHdr.Next() = 0);

            if (ItemPickingLines.Count() > 0) then
                if (ItemExternalLines.Count() > 0) then
                    foreach ItemNo in ItemExternalLines.Keys do begin
                        if not ItemPickingLines.ContainsKey(ItemNo) then begin
                            PostFSNExternalItemEntry.Reset();
                            PostFSNExternalItemEntry.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
                            PostFSNExternalItemEntry.SetRange("Source No.", LSCPRCountingHdr."Reference No.");
                            PostFSNExternalItemEntry.SetRange("Item No.", ItemExternalLines.Get(ItemNo));
                            PostFSNExternalItemEntry.SetRange(Done, false);
                            if PostFSNExternalItemEntry.FindFirst() then begin
                                PostFSNExternalItemEntry."Last error" := 'El Prod. No. ' + ItemNo + ' no esta en las recepciones autorizadas de este pedido';
                                PostFSNExternalItemEntry."Apply Entry" := false;
                                PostFSNExternalItemEntry.Date := WorkDate();
                                PostFSNExternalItemEntry.Modify();
                            end;
                        end;
                    end;
        end else begin
            PostFSNExternalItemEntry.Reset();
            PostFSNExternalItemEntry.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
            PostFSNExternalItemEntry.SetRange("Source No.", FSNExternalItemEntry."Source No.");
            PostFSNExternalItemEntry.SetRange(Done, false);
            if PostFSNExternalItemEntry.Find('-') then begin
                repeat
                    PostFSNExternalItemEntry."Last error" := 'El Pedido No. ' + FSNExternalItemEntry."Source No." + ' no tiene recepciones autorizadas';
                    PostFSNExternalItemEntry."Apply Entry" := false;
                    PostFSNExternalItemEntry.Date := WorkDate();
                    PostFSNExternalItemEntry.Modify();
                until PostFSNExternalItemEntry.Next() = 0;
            end;
            exit;
        end;
        if LSCPRCountingHdr.Find('-') then begin
            repeat begin
                Clear(ItemPickingLines);
                Found := true;
                PurchRcptHdr.Reset();
                if LSCPRCountingHdr.SubTotal = LSCPRCountingHdr.ConfirmarSubTotal then begin
                    LSCPickingReceivinglines.Reset();
                    LSCPickingReceivinglines.SetRange("Document No.", LSCPRCountingHdr."No.");
                    LSCPickingReceivinglines.SetFilter(Quantity, '<>0');
                    if LSCPickingReceivinglines.FindSet() then begin
                        repeat
                            ItemPickingLines.Add(LSCPickingReceivinglines."Item No.", LSCPickingReceivinglines."Quantity (base)");
                        until LSCPickingReceivinglines.Next() = 0;
                    end;
                end;
                if (ItemPickingLines.Count() > 0) then begin
                    if (ItemExternalLines.Count() > 0) then begin
                        foreach ItemNo in ItemPickingLines.Keys do begin
                            if not ItemExternalLines.ContainsKey(ItemNo) then begin
                                Found := false;
                                LSCPRCountingHdr."FSN Message Process" := 'El Prod. No. ' + ItemNo + ' no esta procesado por EBS';
                            end else begin
                                if ItemPickingLines.Get(ItemNo) <> ItemQtyExternalLines.Get(ItemNo) then begin
                                    Found := false;
                                    LSCPRCountingHdr."FSN Message Process" := 'El Prod. No. ' + ItemNo + ' tiene una diferencia de cantidad entre EBS y BC';
                                end;
                            end;
                            if not Found then begin
                                LSCPRCountingHdr.Modify();
                            end;
                        end;
                        if Found then begin
                            if LSCPRCountingHdr."Retail Status"::"Part. receipt" = LSCPRCountingHdr."Retail Status" then
                                ReceivingPartial := 1
                            else
                                ReceivingPartial := 2;

                            LSCPRCountingHdr."FSN Message Process" := '';
                            LSCPRCountingHdr."Counted Date" := Today;
                            LSCPRCountingHdr.Modify();
                            PRConfirm.InitCodeunit(true);
                            PRConfirm.Run(LSCPRCountingHdr);
                            PRPost.SetReceivingPostMethod(2);
                            PRPost.Run(LSCPRCountingHdr);

                            ItemLedgEntry.Reset();
                            ItemLedgEntry.SetRange("Entry Type", EntryType);
                            ItemLedgEntry.SetRange("Document Type", DocumentType);
                            PostFSNExternalItemEntry.Reset();
                            PostFSNExternalItemEntry.SetRange("Entry Type", FSNExternalItemEntry."Entry Type");
                            PostFSNExternalItemEntry.SetRange("Source No.", LSCPRCountingHdr."Reference No.");
                            PostFSNExternalItemEntry.SetRange(Done, false);
                            PurchRcptHdr.SetRange("Order No.", LSCPRCountingHdr."Reference No.");
                            PurchRcptHdr.SetRange("FSN Vendor Invoice No.", LSCPRCountingHdr."Vendor Invoice No.");
                            PurchRcptHdr.SetRange("LSC Receiving/Picking No.", LSCPRCountingHdr."Posted No.");
                            if PurchRcptHdr.FindFirst() then begin
                                RunOnlyOne := true;
                                ItemLedgEntry.SetRange("Document No.", PurchRcptHdr."No.");
                                foreach ItemNo in ItemPickingLines.Keys do begin
                                    ItemLedgEntry.SetRange("Item No.", ItemNo);
                                    ItemLedgEntry.SetFilter(Quantity, '%1', ItemPickingLines.Get(ItemNo));
                                    if ItemLedgEntry.FindFirst() then begin
                                        PostFSNExternalItemEntry.SetRange("Item No.", ItemExternalLines.Get(ItemNo));
                                        if PostFSNExternalItemEntry.FindFirst() then begin
                                            PostFSNExternalItemEntry."No. Mov. BC" := ItemLedgEntry."Entry No.";
                                            PostFSNExternalItemEntry.Done := true;
                                            PostFSNExternalItemEntry."Last error" := '.';
                                            PostFSNExternalItemEntry."Apply Entry" := false;
                                            PostFSNExternalItemEntry.Date := PurchRcptHdr."Posting Date";
                                            PostFSNExternalItemEntry.Modify();
                                        end;
                                    end;
                                end;
                            end else begin
                                LSCPRCountingHdr."FSN Message Process" := 'Error al procesar la recepcion: ' + CopyStr(GetLastErrorText(), 1, 200);
                                LSCPRCountingHdr.Modify();
                            end;
                        end;
                    end;
                end;
            end until (LSCPRCountingHdr.Next() = 0) or RunOnlyOne;
        end;
    end;

    local procedure PurchaseOrderReceiving(EntryType: Enum "Item Ledger Entry Type"; DocumentType: Enum "Item Ledger Document Type"; var FSNExternalItemEntry: Record "FSN External Item Entry"; var breakExternalEntry: Boolean)
    var
        FSNExternalCatalog: Record "FSN External Catalog";
        LSCPRCountingHdr: Record "LSC P/R Counting Header";
        LSCPickingReceivinglines: Record "LSC Picking / Receiving lines";
        LSCRetailReceiving: Page "LSC Retail Receiving";
        PurchRcptHdr: Record "Purch. Rcpt. Header";
        ItemLedgEntry: Record "Item Ledger Entry";
        ItemPickingLines: Dictionary of [Code[20], Integer];
        ItemExternalLines: Dictionary of [Code[20], Integer];
        PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
        BatchPosting: Codeunit "LSC Batch Posting";
        PRPost: Codeunit "LSC Picking/Receiving - Post";
        Found: Boolean;
        ReceivingPartial: Integer;
        ItemNo: Code[20];
        ItemQty: Integer;
    begin
        FSNExternalItemEntry.Reset();
        FSNExternalCatalog.Reset();
        LSCPRCountingHdr.Reset();
        LSCPickingReceivinglines.Reset();

        //Ref.Doc.1
        ///LSCPRCountingHdr.SetRange("Reference No.", 'PED10055023');
        LSCPRCountingHdr.SetRange("FSN Authorized Reception", true);
        //LSCPRCountingHdr.SetRange("FSN Shared with EBS", true);
        LSCPRCountingHdr.SetFilter("FSN Message Process", '%1', '');
        if LSCPRCountingHdr.Find('-') then begin
            repeat begin
                Clear(ItemExternalLines);
                Clear(ItemPickingLines);
                Found := true;
                PurchRcptHdr.Reset();
                if LSCPRCountingHdr.SubTotal = LSCPRCountingHdr.ConfirmarSubTotal then begin
                    LSCPickingReceivinglines.SetRange("Document No.", LSCPRCountingHdr."No.");
                    LSCPickingReceivinglines.SetFilter(Quantity, '<>0');
                    if LSCPickingReceivinglines.FindSet() then begin
                        repeat
                            ItemPickingLines.Add(LSCPickingReceivinglines."Item No.", LSCPickingReceivinglines.Quantity);
                        until LSCPickingReceivinglines.Next() = 0;
                        if (ItemPickingLines.Count() > 0) then begin
                            FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
                            FSNExternalCatalog.SetRange("BC Entry Type", FSNExternalCatalog."BC Entry Type"::Purchase);
                            if FSNExternalCatalog.FindSet() then begin
                                FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                FSNExternalItemEntry.SetRange(Done, false);
                                FSNExternalItemEntry.SetFilter("Last error", '%1', '');
                                FSNExternalItemEntry.SetRange("Source No.", LSCPRCountingHdr."Reference No.");
                                if FSNExternalItemEntry.Find('-') then begin
                                    repeat
                                        ItemExternalLines.Add(FSNExternalItemEntry."Item No.", FSNExternalItemEntry.Quantity);
                                    until FSNExternalItemEntry.Next() = 0;
                                end;
                            end;
                            if (ItemExternalLines.Count() > 0) then begin
                                foreach ItemNo in ItemPickingLines.Keys do begin
                                    if not ItemExternalLines.ContainsKey(ItemNo) then begin
                                        Found := false;
                                        LSCPRCountingHdr."FSN Message Process" := 'El Prod. No. ' + ItemNo + ' no esta procesado por EBS';
                                        break;
                                    end else begin
                                        if ItemPickingLines.Get(ItemNo) <> ItemExternalLines.Get(ItemNo) then begin
                                            Found := false;
                                            LSCPRCountingHdr."FSN Message Process" := 'El Prod. No. ' + ItemNo + ' tiene una diferencia de cantidad entre EBS y BC';
                                            break;
                                        end;
                                    end;
                                    if not Found then begin
                                        LSCPRCountingHdr."FSN Message Process" := 'El Prod. No. ' + ItemNo + ' no esta procesado por EBS';
                                        ReceivingPartial := 1;
                                        break;
                                    end else
                                        ReceivingPartial := 2;
                                end;
                                if not Found then begin
                                    LSCPRCountingHdr.Modify();
                                    FSNExternalItemEntry.SetRange("Item No.", ItemNo);
                                    if FSNExternalItemEntry.FindFirst() then begin
                                        FSNExternalItemEntry."Last error" := LSCPRCountingHdr."FSN Message Process";
                                        FSNExternalItemEntry."Apply Entry" := false;
                                        FSNExternalItemEntry.Modify();
                                    end;
                                end else begin
                                    PRConfirm.InitCodeunit(true);
                                    PRConfirm.Run(LSCPRCountingHdr);
                                    PRPost.SetReceivingPostMethod(ReceivingPartial);
                                    PRPost.Run(LSCPRCountingHdr);
                                    ItemLedgEntry.Reset();
                                    ItemLedgEntry.SetRange("Entry Type", ItemLedgEntry."Entry Type"::"Purchase");
                                    FSNExternalItemEntry.Reset();
                                    FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                                    FSNExternalItemEntry.SetRange("Source No.", LSCPRCountingHdr."Reference No.");
                                    FSNExternalItemEntry.SetRange(Done, false);
                                    PurchRcptHdr.SetRange("Order No.", LSCPRCountingHdr."Reference No.");
                                    PurchRcptHdr.SetRange("FSN Vendor Invoice No.", LSCPRCountingHdr."Vendor Invoice No.");
                                    if PurchRcptHdr.FindFirst() then begin
                                        ItemLedgEntry.SetRange("Document No.", PurchRcptHdr."No.");
                                        foreach ItemNo in ItemPickingLines.Keys do begin
                                            ItemLedgEntry.SetRange("Item No.", ItemNo);
                                            ItemLedgEntry.SetFilter(Quantity, '%1', ItemPickingLines.Get(ItemNo));
                                            if ItemLedgEntry.FindFirst() then begin
                                                FSNExternalItemEntry.SetRange("Item No.", ItemNo);
                                                if FSNExternalItemEntry.FindFirst() then begin
                                                    FSNExternalItemEntry."No. Mov. BC" := ItemLedgEntry."Entry No.";
                                                    FSNExternalItemEntry.Done := true;
                                                    FSNExternalItemEntry."Last error" := '';
                                                    FSNExternalItemEntry."Apply Entry" := false;
                                                    FSNExternalItemEntry.Date := PurchRcptHdr."Posting Date";
                                                    FSNExternalItemEntry.Modify();
                                                end;
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        end;
                    end;
                end;
            end until LSCPRCountingHdr.Next() = 0;
        end;
    end;

    local procedure Transfer()
    var
        FSNExternalItemEntry: Record "FSN External Item Entry";
        FSNExternalCatalog: Record "FSN External Catalog";
        FSNExternalCatLocation: Record "FSN External Catalog";
        ItemLedgEntry: Record "Item Ledger Entry";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ItemJnlLn: Record "Item Journal Line";
        MfgSetup: Record "Manufacturing Setup";
        ItemJnlMgt: Codeunit ItemJnlManagement;
        ItemExternalLines: Dictionary of [Code[20], Integer];
        ItemExternalLines2: Dictionary of [Code[20], Code[20]];
        Text001: Label 'Item Journal Template %1 does not exist.';
        Text002: Label 'Item Journal Batch %1 does not exist.';
        Text003: Label 'FSN External Catalog %1 does not exist.';
        FirtLine: Boolean;
        ItemNo: Code[20];
        ItemLedgEntryNo: Integer;
    begin
        FSNExternalItemEntry.Reset();
        FSNExternalCatalog.Reset();
        ItemJnlBatch.Reset();
        ItemJnlLn.Reset();
        FSNExternalCatLocation.Reset();
        Clear(ItemExternalLines);
        Clear(ItemExternalLines2);
        FirtLine := true;

        if not ItemJnlTemplate.Get('TRANSFERIN') then
            Error(Text001, 'TRANSFERIN')
        else
            if not ItemJnlBatch.Get(ItemJnlTemplate.Name, 'AUTO_EBS') then
                Error(Text002, 'AUTO_EBS');

        ItemJnlLn.SetRange("Journal Template Name", ItemJnlTemplate."Name");
        ItemJnlLn.SetRange("Journal Batch Name", ItemJnlBatch."Name");
        if ItemJnlLn.FindFirst() then begin
            ItemJnlLn.DeleteAll();
        end;

        FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
        FSNExternalCatalog.SetRange("BC Entry Type", FSNExternalCatalog."BC Entry Type"::Transfer);
        if FSNExternalCatalog.FindSet() then begin
            FSNExternalItemEntry.SetCurrentKey("Location Code", "Document No.", "Order Line No.");
            FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
            FSNExternalItemEntry.SetRange(Done, false);
            FSNExternalItemEntry.SetFilter("Last error", '%1', '');
            FSNExternalItemEntry.SetFilter(Quantity, '<>%1', 0);
            FSNExternalItemEntry.SetAscending("Location Code", true);
            FSNExternalItemEntry.SetAscending("Document No.", true);
            FSNExternalItemEntry.SetAscending("Order Line No.", true);
            if FSNExternalItemEntry.FindFirst() then begin
                repeat



                    //Validar que la localizacion sea diferente de vacio
                    if FSNExternalItemEntry."Location Code" = '' then begin
                        FSNExternalItemEntry."Last error" := 'El campo Location Code no puede ser vacio';
                        FSNExternalItemEntry.Modify();
                        break;
                    end;

                    //Validar si existe la Localizacion EBS-BC
                    FSNExternalCatalog.Reset();
                    FSNExternalCatLocation.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Location Code");
                    FSNExternalCatLocation.SetRange("EBS Value", FSNExternalItemEntry."Location Code");
                    if not FSNExternalCatLocation.FindFirst() then begin
                        FSNExternalItemEntry."Last error" := 'El campo Location Code no existe en la FSN External Catalog';
                        FSNExternalItemEntry.Modify();
                        break;
                    end;
                    ItemJnlLn.Reset();
                    ItemJnlLn."Journal Template Name" := ItemJnlTemplate."Name";
                    ItemJnlLn."Journal Batch Name" := ItemJnlBatch."Name";
                    ItemJnlLn."Posting Date" := WorkDate;//consultar si debe tomar fecha de trabajo BC o gestion EBS
                    ItemJnlLn."Document Date" := WorkDate;
                    ItemJnlLn."Document No." := FSNExternalItemEntry."Source No.";
                    ItemJnlLn.Validate("Item No.", FSNExternalItemEntry."Item No.");
                    ItemJnlLn."Location Code" := 'CD';
                    ItemJnlLn."New Location Code" := FSNExternalCatLocation."BC Location Code";
                    ItemJnlLn.Quantity := FSNExternalItemEntry.Quantity;
                    ItemJnlLn.Insert();
                    ItemExternalLines.Add(FSNExternalItemEntry."Item No.", FSNExternalItemEntry."Entry No.");
                    ItemExternalLines2.Add(FSNExternalItemEntry."Item No.", FSNExternalCatLocation."BC Location Code");
                until FSNExternalItemEntry.Next() = 0;
            end;
        end;
        if ItemExternalLines.Count() > 0 then begin
            foreach ItemNo in ItemExternalLines.Keys do begin
                FSNExternalItemEntry.Reset();
                FSNExternalItemEntry.SetRange("Entry No.", ItemExternalLines.Get(ItemNo));
                if FSNExternalItemEntry.FindFirst() then begin
                    //ItemLedgEntryNo := GetItemLedgerEntryNo(ItemLedgEntry."Entry Type"::Transfer, FSNExternalItemEntry."Source No.", ItemExternalLines2.Get(ItemNo), ItemNo, FSNExternalItemEntry.Quantity);
                    if ItemLedgEntryNo <> 0 then begin
                        if FSNExternalItemEntry."No. Mov. BC" = 0 then
                            FSNExternalItemEntry."No. Mov. BC" := ItemLedgEntryNo;
                        FSNExternalItemEntry."Last error" := '';
                        if (FSNExternalItemEntry."No. Mov. BC" <> ItemLedgEntryNo) then
                            FSNExternalItemEntry."Last error" := 'El campo No. Mov. BC no coincide con el Item Ledger Entry No ' + FORMAT(ItemLedgEntryNo);
                        FSNExternalItemEntry.Done := true;
                        FSNExternalItemEntry.Modify();
                        ItemJnlLn.Reset();
                        ItemJnlLn.SetRange("Journal Template Name", ItemJnlTemplate."Name");
                        ItemJnlLn.SetRange("Journal Batch Name", ItemJnlBatch."Name");
                        ItemJnlLn.SetRange("Document No.", FSNExternalItemEntry."Source No.");
                        ItemJnlLn.SetRange("Item No.", ItemNo);
                        if ItemJnlLn.FindFirst() then
                            ItemJnlLn.Delete();
                        ItemExternalLines.Remove(ItemNo);
                        ItemExternalLines2.Remove(ItemNo);
                    end;
                end;
            end;
        end;
        //CODEUNIT.Run(CODEUNIT::"Item Jnl.-Post", ItemJnlLn);
        if ItemExternalLines.Count() > 0 then begin
            foreach ItemNo in ItemExternalLines.Keys do begin
                FSNExternalItemEntry.Reset();
                FSNExternalItemEntry.SetRange("Entry No.", ItemExternalLines.Get(ItemNo));
                if FSNExternalItemEntry.FindFirst() then begin
                    //ItemLedgEntryNo := GetItemLedgerEntryNo(ItemLedgEntry."Entry Type"::Transfer, FSNExternalItemEntry."Source No.", ItemExternalLines2.Get(ItemNo), ItemNo, FSNExternalItemEntry.Quantity);
                    if ItemLedgEntryNo <> 0 then begin
                        if FSNExternalItemEntry."No. Mov. BC" = 0 then begin
                            FSNExternalItemEntry."No. Mov. BC" := ItemLedgEntryNo;
                            FSNExternalItemEntry.Date := WorkDate;
                        end;
                        FSNExternalItemEntry."Last error" := '';
                        if (FSNExternalItemEntry."No. Mov. BC" <> ItemLedgEntryNo) then
                            FSNExternalItemEntry."Last error" := 'El campo No. Mov. BC no coincide con el Item Ledger Entry No ' + FORMAT(ItemLedgEntryNo);
                        FSNExternalItemEntry.Done := true;
                    end else begin
                        FSNExternalItemEntry."Last error" := 'Esta linea no se registro';
                        FSNExternalItemEntry.Done := false;
                    end;
                    FSNExternalItemEntry.Modify();
                end;
            end;
        end;
    end;

    /*
    local procedure GetFSNExternalItemEntryByTypeEntryProcess(
            EntryType: Enum "Item Ledger Entry Type";
            DocumentType: Enum "Item Ledger Document Type";
            var ItemJnlTemplate: Record "Item Journal Template";
            var ItemJnlBatch: Record "Item Journal Batch";
            var PostAutomatically: Boolean;
            var DocumentNo: Code[20])
        var
            FSNExternalItemEntry: Record "FSN External Item Entry";
            CountExterItemEntryByDocument: Record "FSN External Item Entry";
            FSNExternalCatLocation: Record "FSN External Catalog";
            FSNExternalCatalog: Record "FSN External Catalog";
            ItemJnlLn: Record "Item Journal Line";
            Item: Record Item;
            ItemUMP: Record "Item Unit of Measure";
            PurchHdr: Record "Purchase Header";
            PurchLn: Record "Purchase Line";
            breakExternalEntry: Boolean;
            QtyBase: Decimal;
            CountDocumentLine: Integer;
            TotalDocumentLine: Integer;
            ApplyFullDocument: Boolean;
            PrevDocumentNo: Code[20];
            PrevPurchDocumentNo: Code[20];
        begin
            FSNExternalCatalog.Reset();
            FSNExternalCatalog.SetRange("Catalog Name", FSNExternalCatalog."Catalog Name"::"Entry Type");
            FSNExternalCatalog.SetRange("Skip Entry", false);
            FSNExternalCatalog.SetRange("BC Entry Type", EntryType);
            FSNExternalCatalog.SetRange("BC Document Type", DocumentType);
            if FSNExternalCatalog.FindSet() then begin
                repeat
                    FSNExternalItemEntry.Reset();
                    FSNExternalItemEntry.SetCurrentKey("Location Code", "Document No.", "Order Line No.");
                    FSNExternalItemEntry.SetRange("Entry Type", FSNExternalCatalog."EBS Value");
                    FSNExternalItemEntry.SetRange(Done, false);
                    FSNExternalItemEntry.SetFilter("Document No.", '<>%1', '');
                    FSNExternalItemEntry.SetFilter(Quantity, '<>%1', 0);
                    if DocumentNo <> '' then
                        FSNExternalItemEntry.SetRange("Document No.", DocumentNo)
                    else
                        FSNExternalItemEntry.SetFilter("Document No.", '<>%1', '');
                    FSNExternalItemEntry.SetAscending("Location Code", true);
                    FSNExternalItemEntry.SetAscending("Document No.", true);
                    FSNExternalItemEntry.SetAscending("Order Line No.", true);
                    if FSNExternalItemEntry.FindFirst() then begin
                        repeat
                            //Validate Count Rec External Item Entry by Document No
                            if PrevDocumentNo <> FSNExternalItemEntry."Document No." then begin
                                CountDocumentLine := 0;
                                TotalDocumentLine := 0;
                                ApplyFullDocument := true;
                                FSNExternalItemEntry.SetRange("Document No.", FSNExternalItemEntry."Document No.");
                                TotalDocumentLine := FSNExternalItemEntry.Count();
                                if DocumentNo <> '' then
                                    FSNExternalItemEntry.SetRange("Document No.", DocumentNo);
                            end;
                            FSNExternalItemEntry."Apply Entry" := false;
                            FSNExternalItemEntry."Last error" := '';
                            breakExternalEntry := false;
                            QtyBase := 0;
                            Item.Reset();
                            ItemUMP.Reset();
                            //Validate that Item No. is exists and convertir qty to Base UOM
                            if not CheckExistItem(Item, FSNExternalItemEntry, breakExternalEntry) then
                                if not CheckConvertQtyUOMBase(Item, ItemUMP, FSNExternalItemEntry, QtyBase, breakExternalEntry) then
                                    //Validate Lot No. and Expiration Date
                                    if not CheckLotNoEmpty(FSNExternalItemEntry, Item, breakExternalEntry) then
                                        //Validate that Location Code is not empty and exists in FSN External Catalog
                                        CheckEmptyLocationCode(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry);
                            if not breakExternalEntry then
                                case EntryType of
                                    EntryType::Transfer:
                                        begin
                                            //Validate that Source No. is not empty
                                            if not CheckEmptySourceNo(FSNExternalItemEntry, breakExternalEntry) then
                                                //Validate Subinventory y Transfer Subinventory
                                                if not CheckEmptySubInventory(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry) then
                                                    CheckEmptyTransferSubInventory(FSNExternalItemEntry, FSNExternalCatLocation, breakExternalEntry);
                                        end;
                                end;
                            case EntryType of
                                EntryType::Transfer, EntryType::"Positive Adjmt.", EntryType::"Negative Adjmt.":
                                    begin
                                        //Validate Exist Item ledger entry
                                        if not CheckItemLedgerEntryNo(EntryType, DocumentType, Item, FSNExternalItemEntry, FSNExternalCatLocation."BC Location Code", QtyBase, breakExternalEntry) then begin
                                            //Create Reservation Entry by Lot No. and Expiration Date
                                            ItemJnlLn.Init();
                                            ItemJnlLn."Journal Template Name" := ItemJnlTemplate."Name";
                                            ItemJnlLn."Journal Batch Name" := ItemJnlBatch."Name";
                                            ItemJnlLn."Source Code" := ItemJnlTemplate."Source Code";
                                            ItemJnlLn."Entry Type" := EntryType;
                                            ItemJnlLn."Document Type" := DocumentType;
                                            ItemJnlLn."Posting Date" := FSNExternalItemEntry."Posting Date";
                                            ItemJnlLn."Document Date" := FSNExternalItemEntry."Document Date";
                                            ItemJnlLn."Line No." := GetNextLineNo(ItemJnlTemplate."Name", ItemJnlBatch."Name", EntryType, DocumentType, FSNExternalItemEntry."Document No.");
                                            ItemJnlLn."Document No." := FSNExternalItemEntry."Document No.";
                                            ItemJnlLn.Validate("Item No.", Item."No.");
                                            ItemJnlLn.Validate("Unit of Measure Code", Item."Base Unit of Measure");
                                            ItemJnlLn."Location Code" := FSNExternalCatLocation."BC Location Code";
                                            ItemJnlLn."Expiration Date" := FSNExternalItemEntry."Expiration Date";
                                            ItemJnlLn."Lot No." := FSNExternalItemEntry."Lot No.";
                                            //Validate exist lot no, change expiration date the journal item line
                                            if ItemJnlLn."Lot No." <> '' then
                                                CheckLotNoExitsItemLedgerEntry(ItemJnlLn, breakExternalEntry);
                                            ItemJnlLn.Validate(Quantity, QtyBase);
                                            if ItemJnlLn.Insert(true) then begin
                                                if ItemJnlLn."Lot No." <> '' then begin
                                                    if not InsertReservationEntryByLotNo(ItemJnlLn, FSNExternalItemEntry, Item, breakExternalEntry) then
                                                        FSNExternalItemEntry."Apply Entry" := true
                                                end else
                                                    FSNExternalItemEntry."Apply Entry" := true;
                                                if not breakExternalEntry then
                                                    CountDocumentLine += 1;
                                            end else begin
                                                FSNExternalItemEntry."Last error" := Text008 + CopyStr(GetLastErrorText(), 1, 200);
                                            end;
                                        end;
                                        if not FSNExternalItemEntry."Apply Entry" then
                                            ApplyFullDocument := false;
                                        FSNExternalItemEntry."Journal Template Name" := ItemJnlTemplate."Name";
                                        FSNExternalItemEntry."Journal Batch Name" := ItemJnlBatch."Name";
                                        FSNExternalItemEntry.Modify();
                                        if PostAutomatically then
                                            if (CountDocumentLine = TotalDocumentLine) and ApplyFullDocument then
                                                PostJrnlByDocumentNo(EntryType, DocumentType, FSNExternalItemEntry, breakExternalEntry);
                                    end;
                                EntryType::Purchase:
                                    case DocumentType of
                                        DocumentType::"Purchase Return Shipment":
                                            begin
                                                //Validate Exist Item ledger entry
                                                if not CheckItemLedgerEntryNo(EntryType, DocumentType, Item, FSNExternalItemEntry, FSNExternalCatLocation."BC Location Code", QtyBase, breakExternalEntry) then begin
                                                    if PrevDocumentNo <> FSNExternalItemEntry."Document No." then begin
                                                        PurchHdr.Reset();
                                                        PurchHdr.Init();
                                                        PurchHdr."Document Type" := PurchHdr."Document Type"::"Return Order";
                                                        PurchHdr.Validate("Buy-from Vendor No.", 'PROV-000026');
                                                        PurchHdr.InitInsert();
                                                        PurchHdr.Insert();
                                                        PurchHdr.Validate("LSC Store No.", FSNExternalCatLocation."BC Location Code");
                                                        PurchHdr.Validate("Location Code", FSNExternalCatLocation."BC Location Code");
                                                        PurchHdr.Ship := True;
                                                        PurchHdr.Invoice := false;
                                                        PurchHdr.Modify();
                                                    end;
                                                    PurchLn.Init();
                                                    PurchLn."Document No." := PurchHdr."No.";
                                                    PurchLn."Line No." := GetNextLineNo(ItemJnlTemplate."Name", ItemJnlBatch."Name", EntryType, DocumentType, FSNExternalItemEntry."Document No.");
                                                    PurchLn.Validate("Document Type", PurchLn."Document Type"::"Return Order");
                                                    PurchLn.Validate("Type", PurchLn.Type::Item);
                                                    PurchLn.Validate("No.", Item."No.");
                                                    PurchLn.Validate("Unit of Measure", Item."Base Unit of Measure");
                                                    PurchLn.Validate(Quantity, QtyBase);
                                                    if PurchLn.Insert(true) then
                                                        FSNExternalItemEntry."Apply Entry" := true;
                                                    if not breakExternalEntry then
                                                        CountDocumentLine += 1;
                                                end;
                                                if not FSNExternalItemEntry."Apply Entry" then
                                                    ApplyFullDocument := false;
                                                FSNExternalItemEntry."Journal Template Name" := ItemJnlTemplate."Name";
                                                FSNExternalItemEntry."Journal Batch Name" := ItemJnlBatch."Name";
                                                FSNExternalItemEntry.Modify();
                                                if PostAutomatically then
                                                    if (CountDocumentLine = TotalDocumentLine) and ApplyFullDocument then



                                            end;
                                    end;
                            end;

                            PrevDocumentNo := FSNExternalItemEntry."Document No.";
                        until FSNExternalItemEntry.Next() = 0;
                    end;
                until FSNExternalCatalog.Next() = 0;
            end;
        end;
    */
    local procedure TestProcess(var ParameterString: Code[20])
    var
        LSCPRCountingHdr: Record "LSC P/R Counting Header";
        LSCRetailReceiving: Page "LSC Retail Receiving";
        tpage: Page "FSN Purchase Setup Manager";
    begin

    end;

    //Subscriber for Item Journal Post Codeunit
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post", 'OnBeforeCode', '', true, true)]
    local procedure "Item Jnl.-Post_OnBeforeCode"
    (
    var ItemJournalLine: Record "Item Journal Line";
        var HideDialog: Boolean;
        var SuppressCommit: Boolean;
        var IsHandled: Boolean
    )
    begin
        if ItemJournalLine."Journal Template Name" = TemplateName then begin
            if ItemJournalLine."Journal Batch Name" = BatchName then
                HideDialog := true;
        end;
    end;


    //DOCUMENTACION

    /*  DocRef:001 
        Opciones: Tipo Movimiento
        0: Compra
        1: Venta
        2: Ajuste positivo
        3: Ajuste negativo
        4: Transferencia
        5: Consumo
        6: Salida
        7:  
        8: Consumo ensamblado
        9: Salida de ensamblado

        Opciones: Tipo Documento
        0:  
        1: Remisión de venta
        2: Factura venta
        3: Recep. devol. ventas
        4: Nota de crédito de venta
        5: Recepción de compra
        6: Factura compra
        7: Envío devolución compra
        8: Nota de crédito de compra
        9: Envío transfer.
        10: Recep. transfer.
        11: Servicio - Envío
        12: Factura servicio
        13: Nota de crédito de servicio
        14: Ensamblado registrado
        15: Recep. inventario
        16: Envío inventario
        17: Transferencia directa
        20: Ajuste positivo
        21: Ajuste negativo
    */


    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Purchase Header_OnBeforeModifyEvent"
    (
        var Rec: Record "Purchase Header";
        var xRec: Record "Purchase Header";
        RunTrigger: Boolean
    )
    var
        myInt: Integer;
        Vendor: Record Vendor;
    begin
        if rec."Pay-to Vendor Search Name" = '' then
            if Vendor.get(Rec."Pay-to Vendor No.") then begin
                rec."Pay-to Vendor Search Name" := Vendor."Search Name";
                xrec."Pay-to Vendor Search Name" := Vendor."Search Name";

            end;
    end;

}