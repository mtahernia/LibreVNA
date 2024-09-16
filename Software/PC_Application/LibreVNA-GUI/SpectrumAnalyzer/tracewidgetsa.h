#ifndef TRACEWIDGETSA_H
#define TRACEWIDGETSA_H

#include "Traces/tracewidget.h"

class TraceWidgetSA : public TraceWidget
{
public:
    TraceWidgetSA(TraceModel &model, QWidget *parent = nullptr);
public slots:
    virtual void exportDialog() override;
    virtual void importDialog() override;

protected:
    virtual QString defaultParameter() override {return "PORT1";}
};

#endif // TRACEWIDGETSA_H
