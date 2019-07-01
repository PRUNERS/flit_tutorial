/* 
 * Purpose
 * ======= 
 *	Returns the time in seconds used by the process.
 *
 * Note: the timer function call is machine dependent. Use conditional
 *       compilation to choose the appropriate function.
 *
 */

#include "slu_ddefs.h"

#ifdef SUN
/*
 * 	It uses the system call gethrtime(3C), which is accurate to 
 *	nanoseconds. 
*/
#include <sys/time.h>

double SuperLU_timer_() {
    return ( (double)gethrtime() / 1e9 );
}

#else

#ifndef NO_TIMER
#include <time.h>
#include <sys/types.h>
#ifndef WIN32
#include <sys/times.h>
#include <sys/time.h>
#endif
#endif

#ifndef CLK_TCK
#define CLK_TCK 60
#endif

double SuperLU_timer_()
{
#ifdef NO_TIMER
    /* no sys/times.h on WIN32 */
    double tmp;
    tmp = 0.0;
#else
    struct tms use;
    double tmp;
    times(&use);
    tmp = use.tms_utime;
    tmp += use.tms_stime;
#endif
    return (double)(tmp) / CLK_TCK;
}

#endif

