pageextension 50132 "FSN Sales Credit Memo" extends "Sales Credit Memo"
{
    layout
    {
        addafter(SubType)
        {
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
                trigger OnValidate()
                var
                    TEXTV00: Label 'No puede modificar el documento con Sub tipo activo para DTE';
                begin
                    IF NOT ValDTETransac.ValSubTypeDTE(Rec."Sub Type") then
                        Error(TEXTV00);
                end;
            }
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
                trigger OnValidate()
                var
                    TEXTV00: Label 'No puede modificar el documento con Sub tipo activo para DTE';
                begin
                    IF NOT ValDTETransac.ValSubTypeDTE(Rec."Sub Type") then
                        Error(TEXTV00);
                end;
            }
            field("Signature Validation"; Rec."Signature Validation")
            {
                ApplicationArea = All;
                trigger OnValidate()
                var
                    TEXTV00: Label 'No puede modificar el documento con Sub tipo activo para DTE';
                begin
                    IF NOT ValDTETransac.ValSubTypeDTE(Rec."Sub Type") then
                        Error(TEXTV00);
                end;
            }
            field(LocationCode; Rec."Location Code")
            {
                ApplicationArea = All;
            }
        }
        addbefore("Sell-to Contact No.")
        {
            field("VAT Registration No."; Rec."VAT Registration No.")
            {
                ApplicationArea = All;
            }
        }
    }
    actions
    {
        addbefore("F&unctions")
        {
            action(TEST)
            {

                ApplicationArea = Basic, Suite;
                Caption = 'Revertir Factura';
                Ellipsis = true;
                Image = ReverseLines;
                Promoted = true;
                PromotedCategory = Category7;

                trigger OnAction()
                var
                    SalesInvoiceHeader: Record "Sales Invoice Header";
                    Pagef: Page "FSN Get Post Doc";
                    SalesInvHeader: Record "Sales Invoice Header";
                    Text000: Label '¿Desea continuar con la carga del documento N.º %1?';
                    Text001: Label 'ya se encuentra un documento cargado';
                    Text002: Label 'Tipo documento no esta configurado para certifcar DTE';
                    DocumentTypeValidate: Record "Document Sub Type";
                begin

                    if not ValDocument then begin
                        if DocumentTypeValidate.Get(Rec."Sub Type") then
                            if DocumentTypeValidate."DTE Certify" then begin
                                SalesInvHeader.reset;
                                SalesInvHeader.SetRange(SalesInvHeader."Sell-to Customer No.", Rec."Sell-to Customer No.");
                                SalesInvHeader.SetFilter(SalesInvHeader."Cust. Ledger Entry No.", '>%1', 0);
                                Pagef.SetTableView(SalesInvHeader);
                                Pagef.LookupMode := true;
                                if Pagef.RunModal = ACTION::LookupOK then begin
                                    Pagef.GetRecord(SalesInvHeader);
                                    if Confirm(StrSubstNo(Text000, SalesInvHeader."No.")) then BEGIN
                                        if ValidateDocumentType(SalesInvHeader) then begin
                                            IF DocumentTypeValidate.Prefix = '99' THEN
                                                if ValidateDocumentDTE(SalesInvHeader, Rec) then
                                                    CurrPage.Update()
                                                else begin
                                                    Message(Text002);
                                                    exit;
                                                end;
                                            Pagef.SetToSalesHeader(Rec);
                                            Pagef.GetSelectedLine(SalesInvHeader);
                                        end;
                                    END;

                                end;
                            end else
                                Message(Text002);
                    end else
                        Message(Text001);
                end;
            }
        }
    }
    procedure ValDocument(): Boolean
    var
        myInt: Integer;
        SalesLine: Record "Sales Line";
        DocumentTypeValidate: Record "Document Sub Type";
    begin
        if DocumentTypeValidate.get(Rec."Sub Type") then begin
            if DocumentTypeValidate.Prefix = '99' then begin
                SalesLine.Reset();
                SalesLine.SetRange(SalesLine."Document No.", Rec."No.");
                exit(SalesLine.FindFirst());
            end else
                exit(false);
        end;
    end;

    procedure ValidateDocumentDTE(SalesInvHeader: Record "Sales Invoice Header"; var SalesHeader: Record "Sales Header"): Boolean
    var
        FSN_DTE: Record "FSN DTE Transaction Header";
        DocumentTypeValidate: Record "Document Sub Type";
    begin
        if DocumentTypeValidate.Get(Rec."Sub Type") then
            if DocumentTypeValidate.Prefix = '99' then begin
                IF FSN_DTE.GET(COPYSTR(SalesInvHeader."No.", 1, 10), COPYSTR(SalesInvHeader."No.", 11, 10), 0) THEN begin
                    SalesHeader."DTE AuthNumber" := FSN_DTE."DTE AuthNumber";
                    SalesHeader."DTE Invoice" := FSN_DTE."DTE Invoice";
                    SalesHeader."Signature Validation" := FSN_DTE."Signature Validation";
                    SalesHeader."External Document No." := SalesInvHeader."External Document No.";
                    SalesHeader.Modify();
                    exit(true);
                end else begin
                    Message(StrSubstNo(TXTV002, SalesInvHeader."No."));
                    exit(false);
                end;
            end;

        exit(false);
    end;

    procedure ValidateDocumentType(SalesInvHeader: Record "Sales Invoice Header"): Boolean
    var
        DocumentType: Record "Document Sub Type";
        DocumentTypeRecord: Record "Document Sub Type";
    begin
        if DocumentType.get(SalesInvHeader."Sub Type") then begin
            case DocumentType.Prefix of
                '03', '3':
                    begin
                        if DocumentTypeRecord.get(Rec."Sub Type") and not (DocumentTypeRecord.Prefix in ['05', '5']) then begin
                            Message(StrSubstNo(TXTV000, SalesInvHeader."No."));
                            exit(false);
                        end;
                    end;
                '01', '1':
                    begin
                        if DocumentTypeRecord.get(Rec."Sub Type") and (DocumentTypeRecord.Prefix in ['05', '5']) then begin
                            Message(StrSubstNo(TXTV001, SalesInvHeader."No."));
                            exit(false);
                        end;
                    end;
            end;
        end;
        exit(True);
    end;

    var
        ValDTETransac: Codeunit "DTE Validate Transaction";
        TXTV000: Label 'Numero de documento %1 es Credito Fiscal, cambie el sub tipo documento a Nota de Credito';
        TXTV001: Label 'Numero de documento %1 es Factura Consumidor Final, cambie el sub tipo documento, no puede ser tipo Nota de Credito';
        TXTV002: Label 'El Numero de documento %1 no se encuentra certificado en DTE';


}