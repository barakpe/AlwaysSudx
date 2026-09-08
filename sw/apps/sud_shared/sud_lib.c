#include <k5_libs.h>
#include <sud_lib.h>

//-----------------------------------------------------------------------------------------------------------

// Constraint codes (match the solver) 
#define LT  1u  //  same as (unsigned)0b1
#define GT  2u  //  same as (unsigned)0b2

// Decode value nibble
#define VAL(b)((b) & 0x0Fu)

//-----------------------------------------------------------------------------------------------------------

static unsigned char loaded_board[SIZE][SIZE]; // the non completed loaded board memorized for final check

void load_sud_board(unsigned char board[SIZE][SIZE]) {
         
    #ifdef HLCM    
      char sud_in_file_path[200] ;          
      char *k5_path = getenv("MY_K5_PROJ");
      #ifndef _GP_VAL_   
      bm_sprintf(sud_in_file_path,"%s/%s",k5_path,"sw/apps/sud_shared/sudoku_input_20blanks.txt"); // Easy one
      #else           
      //bm_sprintf(sud_in_file_path,"%s,%s/sudoku_input_%s.txt",sud_shared_path,EXPAND_AND_STRINGIFY(_GP_VAL_));  
      bm_sprintf(sud_in_file_path,"%s/%s%s.txt",k5_path,"sw/apps/sud_shared/sudoku_input_",EXPAND_AND_STRINGIFY(_GP_VAL_)); 
      #endif 
      
    #else 
      char sud_in_file_path[80] ;                 
      #ifndef _GP_VAL_   
      //bm_sprintf(sud_in_file_path,"%s","$MY_K5_PROJ/sw/apps/sud_shared/sudoku_input_20blanks.txt"); // Easy one
      bm_sprintf(sud_in_file_path,"%s","app_src_dir/../sud_shared/sudoku_input_20blanks.txt"); // Easy one
      #else    
      //bm_sprintf(sud_in_file_path,"$MY_K5_PROJ/sw/apps/sud_shared/sudoku_input_%s.txt",EXPAND_AND_STRINGIFY(_GP_VAL_));  
      bm_sprintf(sud_in_file_path,"app_src_dir/../sud_shared/sudoku_input_%s.txt",EXPAND_AND_STRINGIFY(_GP_VAL_));  
      #endif
      
    #endif
          
    FILE_REF file_ref ; // assigned by load_hex_file( ... OPEN*) 
    // TODO call some python to generate sudoku_input.txt randomly ...
    load_hex_file(sud_in_file_path, &file_ref, (char *)board, SIZE*SIZE, OPEN_LOAD_CLOSE); // Keep Open 

    // Memorize loaded board for post solve checking

    for (int i=0;i<(SIZE*SIZE);i++) ((uint8_t*)loaded_board)[i] = ((uint8_t*)board)[i] ;
}       

//-----------------------------------------------------------------------------------------------------------


char is_solved(unsigned char board[9][9]) {
    int i, j, n, r, c, br, bc;

    unsigned char seen[9];

    printf("Checking Sudoku rules compatibility\n"); 

    /* check each row */
    for (r = 0; r < 9; r++) {
        for (i = 0; i < 9; i++) seen[i] = 0;
        for (c = 0; c < 9; c++) {
            n = VAL(board[r][c]);
            if (n < 1 || n > 9) return 0;
            if (seen[n - 1]) return 0;
            seen[n - 1] = 1;
        }
    }

    /* check each column */
    for (c = 0; c < 9; c++) {
        for (i = 0; i < 9; i++) seen[i] = 0;
        for (r = 0; r < 9; r++) {
            n = VAL(board[r][c]);
            if (seen[n - 1]) return 0;
            seen[n - 1] = 1;
        }
    }

    /* check each 3x3 box */
    for (br = 0; br < 9; br += 3) {
        for (bc = 0; bc < 9; bc += 3) {
            for (i = 0; i < 9; i++) seen[i] = 0;
            for (i = 0; i < 3; i++) {
                for (j = 0; j < 3; j++) {
                    n = VAL(board[br + i][bc + j]);
                    if (seen[n - 1]) return 0;
                    seen[n - 1] = 1;
                }
            }
        }
    }
    return 1;
}


//-----------------------------------------------------------------------------------------------------------

char check_solved_board(unsigned char solved_board[SIZE][SIZE]) {

    printf("Checking compatibility to original board\n");
    
    for (int r = 0; r < SIZE; r++) {
        for (int c = 0; c < SIZE; c++) {
            if (solved_board[r][c]==0) {
                printf("FAIL: Solved board includes empty cells\n");
                return FALSE ;
            }
            else if (VAL(loaded_board[r][c])!=0) {
                  if (VAL(solved_board[r][c])!=VAL(loaded_board[r][c])){
                     printf("FAIL: solved board[%d][%d]=%d does not match loaded board[%d][%d]=%d\n",
                     r,c,VAL(solved_board[r][c]),r,c,VAL(loaded_board[r][c]));
                     return FALSE ;
                  }
                }
        }
    }

    // Checking Sudoku rules compatibility
    char solved_legal = is_solved(solved_board) ;
    if (!solved_legal) printf("Solved board violates Sudoku rules\n");
    return solved_legal;
}

//-----------------------------------------------------------------------------------------------------------

char verify_inequalities(const unsigned char board[9][9]) {
    char ok = 1;
    unsigned int hc;
    unsigned int rv;
    unsigned int vc;
    unsigned int bv;
    int r,c;
    unsigned int v ;
    
    for (r = 0; r < 9; r++) {
        for (c = 0; c < 9; c++) {
            v = VAL(board[r][c]);
            if (c < 8) {
                hc = (loaded_board[r][c] >> 6) & 0x03u;
                rv = VAL(board[r][c+1]);

                if (hc == LT && !(v < rv)) { 
                   printf("FAIL vert ineq at board[%d,%d]=%d < %d\n",r,c,v,rv);
                   ok=0; 
                }
                if (hc == GT && !(v > rv)) { 
                   printf("FAIL vert ineq at board[%d,%d]=%d > %d\n",r,c,v,rv);
                   ok=0; 
                }


            }
            if (r < 8) {
                vc = (loaded_board[r][c] >> 4) & 0x03u;
                bv = VAL(board[r+1][c]);
                if (vc == LT && !(v < bv)) { 
                    printf("FAIL vert ineq at board[%d,%d]=%d < %d\n",r,c,v,bv); 
                    ok=0;
                }
                if (vc == GT && !(v > bv)) { 
                    printf("FAIL vert ineq at board[%d,%d]=%d > %d\n",r,c,v,bv);
                    ok=0;
                }
            }
        }
    }
 

 
    return ok;
}

//------------------------------------------------------------------------------------------------------------


void print_board_standard(unsigned char board[SIZE][SIZE]) {
    for (int r = 0; r < SIZE; r++) {
        if (r % 3 == 0 && r != 0)
            printf(" ------+-------+------\n");
        for (int c = 0; c < SIZE; c++) {
            if (c % 3 == 0 && c != 0) printf(" |");
            printf(" %d", board[r][c]);
        }
        printf("\n");
    }
    printf("\n\n");   
}



//-------------------------------------------------------------------------------

// Print inequality format board

 /*
 *   +---+---+---+---+---+---+---+---+---+
 *   | 5 > 3 < 4 < 6 < 7 < 8 < 9 > 1 < 2 |
 *   +-^-+-^-+-V-+-^-+-V-+-^-+-^-+-V-+-V-+
 *   | 6 < 7 > 2 > ...
 *
 * Horizontal inequality: replaces '|' between two cells on the data row.
 * Vertical   inequality: replaces middle '-' of '+---+' on the separator
 *   row BELOW the data row ('^' = smaller below, 'V' = smaller above).
 * ======================================================================= */

void print_board(unsigned char board[9][9]) {
    /* Top border */
    for (int c = 0; c < 9; c++) printf("+---");    
    printf("+\n");

    for (int r = 0; r < 9; r++) {
        /* Data row */
        printf("|");
        for (int c = 0; c < 9; c++) {
            unsigned char v = VAL(board[r][c]);
            printf(" %c ", v ? (char)('0' + v) : '.');
            if (c < 8) {
                unsigned int hc = (loaded_board[r][c] >> 6) & 0x03u;
                printf("%c", hc == LT ? '<' : hc == GT ? '>' : '|');
            } else {
                printf("|");
            }
        }
        printf("\n");

        /* Separator row below — carries vert ineqs from this data row */
        for (int c = 0; c < 9; c++) {
            char box_mark = (((r+1)%3)==0) && ((c%3)==0) && (r!=8) && (c!=0)  ;
            unsigned int vc = (r < 8) ? ((loaded_board[r][c] >> 4) & 0x03u) : 0u;
            if (box_mark) printf("%s", vc == LT ? "#-^-" : vc == GT ? "#-V-" : "#---");
            else          printf("%s", vc == LT ? "+-^-" : vc == GT ? "+-V-" : "+---");
        }
        printf("+\n");
    }
}

//------------------------------------------------------------------------------------------------------------

void verify(unsigned char board[9][9]) {
        
      printf("\n=== Application reported Solved ===\n");

      print_board(board);      

      char is_solved_board_ok = check_solved_board(board) ;

      printf("\nSolved board %s basic Sudoku checker\n", is_solved_board_ok ? "PASSED" : "FAILED");

      char is_ineq_ok = verify_inequalities(board); 
      
      printf("\nSolved board %s inequalities checker\n", is_ineq_ok ? "PASSED" : "FAILED");      
     
} 

//------------------------------------------------------------------------------------------------------------
