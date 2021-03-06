load('utils.sage')
load('balanced_basis.sage')
load('inverse_composition.sage')
load('modular_composition.sage')
load('power_projections.sage')

def repeat_test(function, number):
    # Input: 
    #   - function is a python function which does not take any argument and
    #   returns a boolean
    #   - number is a positive integer
    # This repeatedly calls 'function', until it returns False or until
    # 'number' successive calls have returned True
    # Prints a message indicating success or failure
    for k in range(number):
        if not function():
            print number, "instances", " --> wrong"
            return
    print number, "instances", " --> correct"
    return

print "###########################"
print "# Testing MATRIX DIVISION #"
print "###########################"

def test_inverse_truncated():
    p = next_prime(1000000, proof=True)  # using big prime to ensure Prob(A(0) singular) ~ 0
    PolyRing.<x> = GF(p)[]
    m = ZZ.random_element(3,10)
    deg = ZZ.random_element(20,40)
    d = ZZ.random_element(5,40)
    A = Matrix.random(PolyRing, m, m, degree=deg)
    X = inverse_truncated(A, d)
    B = A*X  # should be identity mod x^d
    matrix_truncate(B, d)
    return B == Matrix.identity(PolyRing, m)

print "Testing truncated inverse via Newton iteration..."
repeat_test(test_inverse_truncated, 50)

def test_system_solve_expansion():
    p = next_prime(1000000, proof=True)  # using big prime to ensure Prob(A(0) singular) ~ 0
    PolyRing.<x> = GF(p)[]
    m = ZZ.random_element(3,10)
    n = ZZ.random_element(1,5)
    deg = ZZ.random_element(20,40)
    d = floor(m/n * deg) # this is >= 1
    A = Matrix.random(PolyRing, m, m, degree=deg)
    B = Matrix.random(PolyRing, m, n, degree=d-1)
    X = system_solve_expansion(A, B, d)
    BB = A*X  # should be B mod x^d
    matrix_truncate(BB, d)
    return B == BB

print "Testing expansion of linear system solution..."
repeat_test(test_system_solve_expansion, 50)

def test_matrix_quo_rem():
    p = next_prime(1000000, proof=True)  # using big prime to ensure Prob(B row reduced) ~ 1
    PolyRing.<x> = GF(p)[]
    m = ZZ.random_element(3,10)
    n = ZZ.random_element(1,5)
    # A = random matrix of degree < d
    d = floor(m/n * 30) # this is >= 1
    A = Matrix.random(PolyRing, m, n, degree=d-1)
    # B = random matrix of row degree rdeg
    rdeg = [ZZ.random_element(20,40) for i in range(m)]
    B = Matrix(PolyRing, m, m)
    for i in range(m):
        B[i,:] = Matrix.random(PolyRing, 1, m, degree=rdeg[i])
    Q,R = matrix_quo_rem(A, B)
    if A != B*Q + R:
        return False
    rdegR = R.row_degrees()
    if any([rdegR[i] >= rdeg[i] for i in range(m)]):
        return False
    return True

print "Testing polynomial matrix division with remainder..."
repeat_test(test_matrix_quo_rem, 50)

print "#############################"
print "# Testing APPROXIMANT BASIS #"
print "#############################"

def test_approximant_basis():
    PolyRing.<x> = GF(97)[]
    m = ZZ.random_element(1,6)
    n = ZZ.random_element(2,8)
    order = ZZ.random_element(5,100)
    shift = [ZZ.random_element(0,20) for k in range(n)]
    F = Matrix.random(PolyRing, m, n, degree=order-1)
    P = approximant_basis(F, order, shift)
    # verify that P is in shift-ordered weak Popov form
    if not P.is_weak_popov(row_wise=False, shifts=shift, ordered=True):
        return False
    # verify that F*P = 0 mod x^order
    residual = F*P
    certificate = copy(residual) # for not recomputing later
    matrix_truncate(residual, order)
    if residual != 0:
        return False
    # verify that the columns of P generate all approximants
    # --> cheap verification based on the form of the determinant of P and on a
    # constant matrix having full rank [see Giorgi-Neiger, ISSAC 2018]
    deg_det = sum([P[i,i].degree() for i in range(n)])
    if P.determinant() != (P(1).determinant() * x**deg_det):
        return False
    matrix_shift(certificate, -order)
    mat = Matrix.block([[certificate(0)], [P(0)]])
    if mat.rank() < n:
        return False
    return True

print "Testing minimal approximant basis..."
repeat_test(test_approximant_basis, 15)

print "##########################"
print "# Testing BALANCED BASIS #"
print "##########################"

def test_balanced_basis():
    PolyRing.<y> = GF(997)[]

    n = ZZ.random_element(10,100)
    e = RR.random_element(0.25,0.5)
    m = ceil(n^e) # this is at least 2

    g = PolyRing.random_element(degree=n).monic()
    a = PolyRing.random_element(degree=n-1)
    (B, pow_a) = balanced_basis(g, a, m, store_powers=True)

    # verify that pow_a is formed by powers a^k mod g, for k=0...2*ceil(n/m)-1
    k=0
    ak = 1
    while k < len(pow_a) and pow_a[k] == ak:
        k += 1
        ak = (ak*a) % g
    if k < len(pow_a) or len(pow_a) != 2*ceil(n/m):
        print len(pow_a)
        print 2*ceil(n/m)
        return False

    # verify that B is a generating set for I = <x-a(y), g(y)>
    PolyRingXY.<X,Y> = GF(997)[]
    pols_B = [sum([B[i,j](X) * Y^i for i in range(m)]) for j in range(m)]
    if PolyRingXY.ideal(X-a(Y), g(Y)) != PolyRingXY.ideal(pols_B):
        return False

    # verify that the polynomials in this generating set have x-degree at most
    # ceil(n/m)   (they have y-degree < m by construction)
    for i in range(m):
        for j in range(m):
            if B[i,j].degree() > ceil(n/m):
                return False

    return True

print "Testing balanced basis..."
repeat_test(test_balanced_basis, 20)

print "###############################"
print "# Testing INVERSE COMPOSITION #"
print "###############################"

def test_inverse_composition():
    PolyRing.<y> = GF(997)[]

    n = ZZ.random_element(10,200)
    e = RR.random_element(0.25,0.5)
    m = ceil(n^e) # this is at least 2

    g = PolyRing.random_element(degree=n).monic()
    a = PolyRing.random_element(degree=n-1)
    b = PolyRing.random_element(degree=n-1)
    h = inverse_composition(g, a, b, m)

    # verify that h(x) has degree less than n
    if h.degree() >= n:
        return False

    # verify that h(a) = b mod g
    QuoRing.<yy> = PolyRing.quotient(g)
    if h(a(yy)) != b(yy):
        return False

    return True

print "Testing inverse composition..."
repeat_test(test_inverse_composition, 20)

print "#######################"
print "# Testing COMPOSITION #"
print "#######################"

def test_composition():
    PolyRing.<y> = GF(997)[]
    PolyRingX.<x> = GF(997)[]

    n = ZZ.random_element(10,200)
    e = RR.random_element(0.25,0.5)
    m = ceil(n^e) # this is at least 2

    g = PolyRing.random_element(degree=n).monic()
    a = PolyRing.random_element(degree=n-1)
    h = PolyRingX.random_element(degree=n-1)
    b = modular_composition(g, a, h, m)

    # verify that b(y) has degree less than n
    if b.degree() >= n:
        return False

    # verify that h(a) = b mod g
    QuoRing.<yy> = PolyRing.quotient(g)
    if h(a(yy)) != b(yy):
        return False

    return True

print "Testing composition..."
repeat_test(test_composition, 20)

print "#############################"
print "# Testing POWER PROJECTIONS #"
print "#############################"

def test_power_projections():
    PolyRing.<y> = GF(997)[]
    PolyRingX.<x> = GF(997)[]

    n = ZZ.random_element(10,200)
    e = RR.random_element(0.25,0.5)
    m = ceil(n^e) # this is at least 2

    g = PolyRing.random_element(degree=n).monic()
    a = PolyRing.random_element(degree=n-1)
    elly = [GF(997).random_element() for k in range(n)]
    ella = power_projections(g, a, elly, m)

    # verify that ella has length n
    if len(ella) != n:
        return False

    # verify that ella[k] = ell(a^k mod g)
    if ella[0] != elly[0]:
        return False
    QuoRing.<yy> = PolyRing.quotient(g)
    ak = a(yy)
    for k in range(1,n):
        coeffs = list(ak)
        coeffs = coeffs + [0]*(n-len(coeffs))
        ellak = (Matrix(GF(997),1,n,elly) * Matrix(GF(997),n,1,coeffs))[0,0]
        if ellak != ella[k]:
            return False
        ak = ak * a(yy)

    return True

print "Testing power projections..."
repeat_test(test_power_projections, 15)
