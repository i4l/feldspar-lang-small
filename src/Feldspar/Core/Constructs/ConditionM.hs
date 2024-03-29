{-# LANGUAGE GADTs #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}

--
-- Copyright (c) 2009-2011, ERICSSON AB
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
--     * Redistributions of source code must retain the above copyright notice,
--       this list of conditions and the following disclaimer.
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--     * Neither the name of the ERICSSON AB nor the names of its contributors
--       may be used to endorse or promote products derived from this software
--       without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

module Feldspar.Core.Constructs.ConditionM
    ( ConditionM (..)
    ) where

import Language.Syntactic
import Language.Syntactic.Constructs.Binding

import Feldspar.Core.Types
import Feldspar.Core.Interpretation
import Feldspar.Core.Constructs.Logic

data ConditionM m a
  where
    ConditionM :: (Monad m, Type a) =>
                  ConditionM m (Bool :-> m a :-> m a :-> Full (m a))

instance Semantic (ConditionM m)
  where
    semantics ConditionM = Sem "if" ifM
      where
        ifM cond e t = if cond then e else t

instance Equality (ConditionM m) where equal = equalDefault; exprHash = exprHashDefault
instance Render   (ConditionM m) where renderArgs = renderArgsDefault
instance ToTree   (ConditionM m)
instance Eval     (ConditionM m) where evaluate = evaluateDefault
instance EvalBind (ConditionM m) where evalBindSym = evalBindSymDefault
instance Sharable (ConditionM m)

instance AlphaEq dom dom dom env =>
    AlphaEq (ConditionM m) (ConditionM m) dom env
  where
    alphaEqSym = alphaEqSymDefault

instance LatticeSize1 m => SizeProp (ConditionM m)
  where
    sizeProp ConditionM (_ :* WrapFull t :* WrapFull f :* Nil) =
        mergeSize t (infoSize t) (infoSize f)

instance ( ConditionM m :<: dom
         , (Logic :|| Type) :<: dom
         , OptimizeSuper dom
         , LatticeSize1 m
         )
      => Optimize (ConditionM m) dom
  where
    constructFeatOpt _ ConditionM (c :* t :* f :* Nil)
        | Just c' <- viewLiteral c = return $ if c' then t else f

    constructFeatOpt _ ConditionM (_ :* t :* f :* Nil)
        | alphaEq t f = return t

    constructFeatOpt opts cond@ConditionM ((op :$ c) :* t :* f :* Nil)
        | Just (C' Not) <- prjF op
        = constructFeat opts cond (c :* f :* t :* Nil)

    constructFeatOpt opts a args = constructFeatUnOpt opts a args

    constructFeatUnOpt opts ConditionM args@(_ :* t :* _ :* Nil)
        | Info {infoType = tType} <- getInfo t
        = constructFeatUnOptDefaultTyp opts tType ConditionM args

